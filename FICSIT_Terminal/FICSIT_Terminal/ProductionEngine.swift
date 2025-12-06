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
        // On essaie de produire les goals petit à petit en consommant les ressources
        // Si la recette 1 est bloquée, on essaie la recette 2 (si active)
        
        var goalProduction: [UUID: Double] = [:]
        for goal in goals { goalProduction[goal.id] = 0.0 }
        
        var loop = true
        var iterations = 0
        // StepSize adaptatif : plus grand pour les calculs simples, plus petit pour les complexes
        let baseStepSize = ProductionConfig.defaultStepSize
        let maxIterations = ProductionConfig.maxIterations
        
        // Calculer un stepSize adaptatif basé sur les ressources disponibles
        let totalResources = inventory.values.reduce(0, +)
        let adaptiveStepSize = max(baseStepSize, min(1.0, totalResources / 100.0))
        let stepSize = adaptiveStepSize
        
        // Variables pour détecter les boucles stériles
        var lastInventoryTotal: Double = 0
        var stagnantIterations = 0
        let maxStagnantIterations = 50 // Arrêter si on n'a pas progressé depuis 50 itérations
        
        while loop && iterations < maxIterations {
            iterations += 1
            var producedSomething = false
            
            // Calculer le total de l'inventaire pour détecter la stagnation
            let currentInventoryTotal = inventory.values.reduce(0, +)
            
            for goal in goals {
                // On essaie de produire 'stepSize' de ce goal
                let item = goal.item.name
                let recipes = activeRecipes[item] ?? []
                let defaultRecipe = db.getRecipesOptimized(producing: item).first(where: { !$0.isAlternate })
                let candidates: [Recipe]
                if recipes.isEmpty {
                    if let defaultRecipe = defaultRecipe {
                        candidates = [defaultRecipe]
                    } else {
                        candidates = []
                    }
                } else {
                    candidates = recipes
                }
                
                // On cherche une recette capable de produire ce pas
                for recipe in candidates {
                    do {
                        if try canAfford(recipe: recipe, itemName: item, qty: stepSize, inventory: inventory, userRecipes: activeRecipes) {
                            // On paie
                            try pay(recipe: recipe, itemName: item, qty: stepSize, inventory: &inventory, userRecipes: activeRecipes)
                            // On enregistre
                            goalProduction[goal.id] = (goalProduction[goal.id] ?? 0) + stepSize
                            
                            // On note la recette utilisée pour le rapport final
                            var itemPlan = productionPlan[item] ?? [:]
                            itemPlan[recipe.id] = (itemPlan[recipe.id] ?? 0) + stepSize
                            productionPlan[item] = itemPlan
                            
                            producedSomething = true
                            break // On a réussi pour ce goal, on passe au suivant (pour équilibrer)
                        }
                    } catch {
                        // Ignorer les erreurs de coût pour cette recette, essayer la suivante
                        continue
                    }
                }
            }
            
            // Détecter si l'inventaire n'a pas changé (stagnation)
            // Utiliser une tolérance pour les comparaisons de nombres flottants
            if abs(currentInventoryTotal - lastInventoryTotal) < 0.001 {
                stagnantIterations += 1
                if stagnantIterations >= maxStagnantIterations {
                    // On n'a pas progressé depuis trop longtemps, arrêter
                    loop = false
                    break
                }
            } else {
                stagnantIterations = 0
                lastInventoryTotal = currentInventoryTotal
            }
            
            if !producedSomething { loop = false }
        }
        
        // Vérifier si on a atteint la limite d'itérations
        if iterations >= maxIterations {
            throw ProductionError.calculationTimeout
        }
        
        // D. Lissage
        var finalRates: [UUID: Double] = [:]
        for (id, amount) in goalProduction { finalRates[id] = floor(amount) }
        
        // --- PARTIE 3 : SINK ---
        // On recalcule le surplus réel basé sur l'inventaire restant
        let surplusPool = inventory // Ce qui reste après la boucle est le surplus
        
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
        // Cette fois, on génère les steps à partir de notre 'productionPlan' qui contient les recettes mixtes
        var steps: [ConsolidatedStep] = []
        
        // Fonction récursive pour ajouter les machines intermédiaires
        // (Car notre boucle n'a calculé que les produits finaux)
        // C'est complexe. Pour la V3, on va simplifier :
        // On relance une simulation "Cost Only" basée sur les 'finalRates' et la recette principale
        // pour générer les machines intermédiaires.
        // *Note: Le vrai multi-recette complet demande un graphe de dépendance complet.
        // Ici, on va assumer que les ingrédients utilisent leur recette principale.*
        
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
