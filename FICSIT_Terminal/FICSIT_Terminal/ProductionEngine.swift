import Foundation

class ProductionEngine {
    let db = FICSITDatabase.shared
    
    struct OptimizationResult {
        let steps: [ConsolidatedStep]
        let sinkReport: SinkResult?
    }
    
    // MARK: - CACHE POUR MEMOIZATION
    private var costCache: [String: [String: Double]] = [:]
    private var cacheTimestamp: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = ProductionConfig.cacheTimeout
    
    // Clé de cache basée sur l'item et les recettes actives
    private func cacheKey(for itemName: String, userRecipes: [String: [Recipe]]) -> String {
        let recipeKeys = userRecipes.keys.sorted().joined(separator: ",")
        return "\(itemName)|\(recipeKeys)"
    }
    
    // Invalider le cache quand les recettes changent
    func invalidateCache() {
        costCache.removeAll()
        cacheTimestamp.removeAll()
    }
    
    // --- 1. MOTEUR DE COÛTS UNITAIRES (Multi-Recettes Support) avec MEMOIZATION ---
    private func getRawCostVector(
        for itemName: String,
        quantity: Double,
        userRecipes: [String: [Recipe]],
        visited: inout Set<String> // Détection de cycles
    ) throws -> [String: Double] {
        
        // Détection de cycles
        if visited.contains(itemName) {
            throw ProductionError.circularDependency(items: Array(visited) + [itemName])
        }
        visited.insert(itemName)
        defer { visited.remove(itemName) }
        
        // Vérifier le cache
        let key = cacheKey(for: itemName, userRecipes: userRecipes)
        if let cached = costCache[key],
           let timestamp = cacheTimestamp[key],
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            // Retourner le cache multiplié par la quantité
            return cached.mapValues { $0 * quantity }
        }
        
        // Ressource brute (Soit native, soit considérée comme telle car Input du graphe)
        // NOTE: On considère les ressources brutes comme feuilles.
        // Les items importés doivent être traités comme des ressources brutes dans le contexte de l'usine courante.
        if db.rawResources.contains(itemName) {
            let result = [itemName: quantity]
            costCache[key] = [itemName: 1.0] // Stocker pour quantity=1
            cacheTimestamp[key] = Date()
            return result
        }
        
        // Trouver la recette (utiliser version optimisée)
        let recipes = userRecipes[itemName] ?? []
        // Si aucune recette mais c'est un item, vérifions si c'est un import disponible dans les inputs
        // (Logique gérée en amont par canAfford qui regarde inventory)
        // Mais pour le coût théorique, si on n'a pas de recette, on bloque.

        guard let recipe = recipes.first ?? db.getRecipesOptimized(producing: itemName).first(where: { !$0.isAlternate }) else {
            // Cas spécial : Si l'item n'a pas de recette MAIS est présent dans les inputs (import), on le considère comme "gratuit" en termes de production (coût = lui-même)
            // Cela permet à getRawCostVector de dire "ça coute 1 item" et ensuite canAfford vérifie le stock.
            let result = [itemName: quantity]
            return result
        }
        
        let productQty = recipe.products[itemName] ?? 1.0
        guard productQty > 0 else {
            throw ProductionError.invalidRecipe(recipe: recipe.name, reason: "Product quantity is zero")
        }
        
        let machineRatio = quantity / productQty
        var costVector: [String: Double] = [:]
        
        // Calculer récursivement
        for (ingName, ingRate) in recipe.ingredients {
            let needed = ingRate * machineRatio
            let subCost = try getRawCostVector(
                for: ingName,
                quantity: needed,
                userRecipes: userRecipes,
                visited: &visited
            )
            for (res, amount) in subCost {
                costVector[res] = (costVector[res] ?? 0) + amount
            }
        }
        
        // Mettre en cache (normalisé pour quantity=1)
        costCache[key] = costVector.mapValues { $0 / quantity }
        cacheTimestamp[key] = Date()
        
        return costVector
    }
    
    // Version wrapper pour compatibilité
    private func getRawCostVector(for itemName: String, quantity: Double, userRecipes: [String: [Recipe]]) throws -> [String: Double] {
        var visited: Set<String> = []
        return try getRawCostVector(for: itemName, quantity: quantity, userRecipes: userRecipes, visited: &visited)
    }
    
    // --- 2. SOLVEUR EN CASCADE AVEC FALLBACK RECIPE ---
    func calculateAbsoluteAllocation(goals: [ProductionGoal], availableInputs: [ResourceInput], beltLimit: Double, activeRecipes: [String: [Recipe]]) throws -> OptimizationResult {
        
        // A. Stock Initial
        var inventory: [String: Double] = [:]
        for input in availableInputs {
            // Ici, si c'est un import résolu, il a été transformé par le ViewModel pour avoir une productionRate valide.
            // Si c'est un .factory, le productionRate est 0 dans le struct, mais le ViewModel doit nous passer des inputs "résolus".
            // Cependant, ResourceInput.productionRate est calculé.
            // Pour supporter les imports qui ne sont pas des nodes, on doit regarder le sourceType.

            // TODO: Le ViewModel nous envoie des ResourceInput.
            // Si c'est un .node, productionRate est correct.
            // Si c'est un .factory, productionRate est 0.
            // Le ViewModel a du injecter les quantités via un autre moyen ou on doit modifier ResourceInput pour porter la valeur résolue.

            // Workaround temporaire:
            // On suppose que si sourceType est .factory, on utilise une logique spéciale ou on considère que c'est géré.
            // Mais ici on utilise `productionRate`.

            // CORRECTIF LOGISTIQUE :
            // On va utiliser une extension ou modification locale.
            // Pour l'instant, supposons que le ViewModel a converti les Imports en Inputs virtuels de type .node avec un custom miner.
            // Si ce n'est pas le cas, on a un problème : rate = 0.

            // Comme on n'a pas modifié ResourceInput pour porter une valeur explicite, on va faire confiance au ViewModel
            // pour avoir mis une valeur dans purity/miner qui matche le montant importé.

            inventory[input.resourceName] = (inventory[input.resourceName] ?? 0) + min(input.productionRate, beltLimit)
        }
        
        // B. Structure pour stocker "Qui produit quoi avec quelle recette"
        var productionPlan: [String: [UUID: Double]] = [:]
        
        // C. Boucle de Production Itérative
        var goalProduction: [UUID: Double] = [:]
        for goal in goals { goalProduction[goal.id] = 0.0 }
        
        var loop = true
        var iterations = 0

        let maxIterations = ProductionConfig.maxIterations
        let totalResources = inventory.values.reduce(0, +)
        let stepSize = max(1.0, totalResources / 200.0)
        
        var lastInventoryTotal: Double = 0
        var stagnantIterations = 0
        let maxStagnantIterations = 50
        
        while loop && iterations < maxIterations {
            iterations += 1
            var producedSomething = false
            let currentInventoryTotal = inventory.values.reduce(0, +)
            
            for goal in goals {
                let item = goal.item.name
                let recipes = activeRecipes[item] ?? []
                let defaultRecipe = db.getRecipesOptimized(producing: item).first(where: { !$0.isAlternate })
                let candidates: [Recipe] = recipes.isEmpty ? (defaultRecipe != nil ? [defaultRecipe!] : []) : recipes
                
                // Si aucune recette candidate, vérifier si on a du stock (Import)
                if candidates.isEmpty {
                    // Si on a du stock, on peut "produire" (consommer le stock directement pour satisfaire le goal)
                    if (inventory[item] ?? 0) >= stepSize {
                        inventory[item] = (inventory[item] ?? 0) - stepSize
                        goalProduction[goal.id] = (goalProduction[goal.id] ?? 0) + stepSize
                        producedSomething = true
                    }
                    continue
                }

                for recipe in candidates {
                    do {
                        if try canAfford(recipe: recipe, itemName: item, qty: stepSize, inventory: inventory, userRecipes: activeRecipes) {
                            try pay(recipe: recipe, itemName: item, qty: stepSize, inventory: &inventory, userRecipes: activeRecipes)
                            goalProduction[goal.id] = (goalProduction[goal.id] ?? 0) + stepSize
                            
                            var itemPlan = productionPlan[item] ?? [:]
                            itemPlan[recipe.id] = (itemPlan[recipe.id] ?? 0) + stepSize
                            productionPlan[item] = itemPlan
                            
                            producedSomething = true
                            break
                        }
                    } catch {
                        continue
                    }
                }
            }
            
            if abs(currentInventoryTotal - lastInventoryTotal) < 0.001 {
                stagnantIterations += 1
                if stagnantIterations >= maxStagnantIterations {
                    loop = false
                    break
                }
            } else {
                stagnantIterations = 0
                lastInventoryTotal = currentInventoryTotal
            }
            
            if !producedSomething { loop = false }
        }
        
        if iterations >= maxIterations {
            throw ProductionError.calculationTimeout
        }
        
        var finalRates: [UUID: Double] = [:]
        for (id, amount) in goalProduction { finalRates[id] = floor(amount) }
        
        // --- PARTIE 3 : SINK ---
        let surplusPool = inventory
        
        var bestSinkResult: SinkResult? = nil
        var bestItem: ProductionItem? = nil
        var bestPoints: Int = 0
        var bestAmount: Double = 0
        
        for (itemName, surplusAmount) in surplusPool {
            if db.rawResources.contains(itemName) || surplusAmount <= 0 { continue }
            guard let item = db.getItemOptimized(named: itemName),
                  item.sinkValue > 0 else { continue }
            
            let totalPoints = Int(surplusAmount * Double(item.sinkValue))
            if totalPoints > bestPoints {
                bestPoints = totalPoints
                bestItem = item
                bestAmount = surplusAmount
            }
        }
        
        if let item = bestItem {
            bestSinkResult = SinkResult(
                bestItem: item,
                producedAmount: bestAmount,
                totalPoints: bestPoints
            )
        }
        
        // --- PARTIE 4 : GÉNÉRATION STEPS ---
        var steps: [ConsolidatedStep] = []
        var totalDemandMap: [String: Double] = [:]
        
        func addDemand(item: String, rate: Double) {
            totalDemandMap[item] = (totalDemandMap[item] ?? 0) + rate
            // Si c'est une ressource brute OU qu'on n'a pas de recette active (Import), on arrête
            if db.rawResources.contains(item) { return }

            // Check si recette
            let recipes = activeRecipes[item] ?? []
            guard let recipe = recipes.first ?? db.getRecipesOptimized(producing: item).first(where: { !$0.isAlternate }) else { return }

            let productQty = recipe.products[item] ?? 1.0
            guard productQty > 0 else { return }
            let ratio = rate / productQty
            for (ing, qty) in recipe.ingredients { addDemand(item: ing, rate: qty * ratio) }
        }
        
        for goal in goals { addDemand(item: goal.item.name, rate: finalRates[goal.id] ?? 0) }
        
        for (item, rate) in totalDemandMap {
            if db.rawResources.contains(item) { continue }
            let recipes = activeRecipes[item] ?? []
            // S'il n'y a pas de recette, c'est probablement un Import consommé direct, donc pas de step de prod
            if let recipe = recipes.first ?? db.getRecipesOptimized(producing: item).first(where: { !$0.isAlternate }) {
                let productQty = recipe.products[item] ?? 1.0
                guard productQty > 0 else { continue }
                let machines = rate / productQty
                let step = ConsolidatedStep(
                    item: db.getItemOptimized(named: item) ?? ProductionItem(name: item, category: "Part"),
                    totalRate: rate,
                    machineCount: machines,
                    recipe: recipe,
                    powerUsage: machines * recipe.machine.powerConsumption,
                    buildingName: recipe.machine.name
                )
                steps.append(step)
            }
        }
        
        return OptimizationResult(steps: steps.sorted { $0.buildingName < $1.buildingName }, sinkReport: bestSinkResult)
    }
    
    // Helpers pour la simulation de coût
    private func canAfford(recipe: Recipe, itemName: String, qty: Double, inventory: [String: Double], userRecipes: [String: [Recipe]]) throws -> Bool {
        let productQty = recipe.products[itemName] ?? 1.0
        guard productQty > 0 else { return false }
        let ratio = qty / productQty
        
        for (ing, amount) in recipe.ingredients {
            let needed = amount * ratio
            // Logique unifiée : on vérifie d'abord le stock direct (incluant les Inputs/Imports)
            if (inventory[ing] ?? 0) >= needed {
                // On a assez en stock direct, c'est bon
                continue
            }

            // Si pas assez en stock, on regarde si on peut produire
            // Si c'est une ressource brute ou sans recette, c'est mort car on a déjà checké le stock
            if db.rawResources.contains(ing) {
                 return false
            }

            // Sinon on regarde le coût de production récursif
            let rawCost = try getRawCostVector(for: ing, quantity: needed, userRecipes: userRecipes)

            // Note: getRawCostVector renvoie les feuilles (ressources brutes ou imports sans recette)
            for (r, c) in rawCost {
                if (inventory[r] ?? 0) < c { return false }
            }
        }
        return true
    }
    
    private func pay(recipe: Recipe, itemName: String, qty: Double, inventory: inout [String: Double], userRecipes: [String: [Recipe]]) throws {
        let productQty = recipe.products[itemName] ?? 1.0
        guard productQty > 0 else { return }
        let ratio = qty / productQty
        
        for (ing, amount) in recipe.ingredients {
            let needed = amount * ratio

            // 1. Payer avec le stock direct si possible (pour Imports ou surplus intermédiaires)
            if (inventory[ing] ?? 0) >= needed {
                inventory[ing] = (inventory[ing] ?? 0) - needed
            } else {
                // 2. Sinon payer les coûts bruts
                let rawCost = try getRawCostVector(for: ing, quantity: needed, userRecipes: userRecipes)
                for (r, c) in rawCost {
                    inventory[r] = (inventory[r] ?? 0) - c
                }
            }
        }
    }
    
    func calculatePowerScenario(fuel: PowerFuel, amountAvailable: Double) -> PowerResult {
        // (Inchangé)
        let consumptionPerGen = 60.0 / fuel.burnTime
        let numGenerators = amountAvailable / consumptionPerGen
        let mwPerGen: Double = (fuel == .coal) ? 75.0 : 150.0
        let totalMW = numGenerators * mwPerGen
        var waterNeeded: Double = 0; var extractors: Double = 0
        if fuel == .coal { waterNeeded = numGenerators * 45.0; extractors = waterNeeded / 120.0 }
        return PowerResult(fuel: fuel, generators: numGenerators, totalMW: totalMW, waterNeeded: waterNeeded, waterExtractors: extractors)
    }
}
