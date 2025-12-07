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
        
        // Ressource brute
        if db.rawResources.contains(itemName) {
            let result = [itemName: quantity]
            costCache[key] = [itemName: 1.0] // Stocker pour quantity=1
            cacheTimestamp[key] = Date()
            return result
        }
        
        // Trouver la recette (utiliser version optimisée)
        let recipes = userRecipes[itemName] ?? []
        guard let recipe = recipes.first ?? db.getRecipesOptimized(producing: itemName).first(where: { !$0.isAlternate }) else {
            throw ProductionError.noRecipeFound(item: itemName)
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
            inventory[input.resourceName] = (inventory[input.resourceName] ?? 0) + min(input.productionRate, beltLimit)
        }
        
        // B. Structure pour stocker "Qui produit quoi avec quelle recette"
        // [ItemID : [RecipeID : QuantitéProduite]]
        var productionPlan: [String: [UUID: Double]] = [:]
        
        // C. Boucle de Production Itérative (Par petits pas)
        var goalProduction: [UUID: Double] = [:]
        for goal in goals { goalProduction[goal.id] = 0.0 }
        
        var loop = true
        var iterations = 0

        let baseStepSize = ProductionConfig.defaultStepSize
        let maxIterations = ProductionConfig.maxIterations
        let totalResources = inventory.values.reduce(0, +)
        // Correction Critique : stepSize doit être suffisamment grand pour converger
        // Ancienne formule limitait à 1.0 : max(baseStepSize, min(1.0, totalResources / 100.0))
        // Nouvelle formule : On prend au moins 1.0, et on augmente si les ressources sont énormes
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
        
        // Calculer le meilleur item à envoyer au Sink
        var bestItem: ProductionItem? = nil
        var bestPoints: Int = 0
        var bestAmount: Double = 0
        
        for (itemName, surplusAmount) in surplusPool {
            // Ignorer les ressources brutes et les items sans valeur Sink
            if db.rawResources.contains(itemName) || surplusAmount <= 0 { continue }
            
            // Trouver l'item dans la base de données pour obtenir sa sinkValue (version optimisée)
            guard let item = db.getItemOptimized(named: itemName),
                  item.sinkValue > 0 else { continue }
            
            // Calculer les points totaux par minute
            let totalPoints = Int(surplusAmount * Double(item.sinkValue))
            
            // Garder le meilleur (celui qui génère le plus de points)
            if totalPoints > bestPoints {
                bestPoints = totalPoints
                bestItem = item
                bestAmount = surplusAmount
            }
        }
        
        // Créer le résultat Sink si on a trouvé un item valide
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
            if db.rawResources.contains(item) { return }
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
            if db.rawResources.contains(ing) {
                if (inventory[ing] ?? 0) < needed { return false }
            } else {
                // Pour un ingrédient manufacturé, on vérifie si on peut le produire récursivement
                // On utilise getRawCostVector pour estimer les coûts bruts
                let rawCost = try getRawCostVector(for: ing, quantity: needed, userRecipes: userRecipes)
                for (r, c) in rawCost {
                    if (inventory[r] ?? 0) < c { return false }
                }
            }
        }
        return true
    }
    
    private func pay(recipe: Recipe, itemName: String, qty: Double, inventory: inout [String: Double], userRecipes: [String: [Recipe]]) throws {
        // Déduit les ressources brutes nécessaires pour fabriquer 'qty' via 'recipe'
        // On utilise getRawCostVector pour simplifier la chaîne de dépendance
        let productQty = recipe.products[itemName] ?? 1.0
        guard productQty > 0 else { return }
        let ratio = qty / productQty
        
        for (ing, amount) in recipe.ingredients {
            let needed = amount * ratio
            let rawCost = try getRawCostVector(for: ing, quantity: needed, userRecipes: userRecipes)
            for (r, c) in rawCost {
                inventory[r] = (inventory[r] ?? 0) - c
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
