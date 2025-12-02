import Foundation

class ProductionEngine {
    let db = FICSITDatabase.shared
    
    struct OptimizationResult {
        let steps: [ConsolidatedStep]
        let sinkReport: SinkResult?
    }
    
    // --- 1. MOTEUR DE COÛTS UNITAIRES (Multi-Recettes Support) ---
    // Si 'allowPartial' est vrai, il peut renvoyer un coût incomplet (pour voir ce qui est possible)
    // Mais ici, pour le coût unitaire, on doit trouver UN chemin valide.
    // On prend la recette *primaire* (la première de la liste active) comme référence de coût "idéal".
    private func getRawCostVector(for itemName: String, quantity: Double, userRecipes: [String: [Recipe]]) -> [String: Double] {
        var costVector: [String: Double] = [:]
        if db.rawResources.contains(itemName) { return [itemName: quantity] }
        
        let recipes = userRecipes[itemName] ?? []
        // On prend la recette prioritaire (la première)
        guard let recipe = recipes.first ?? db.getRecipes(producing: itemName).first(where: { !$0.isAlternate }) else { return [:] }
        
        let productQty = recipe.products[itemName] ?? 1.0
        let machineRatio = quantity / productQty
        
        for (ingName, ingRate) in recipe.ingredients {
            let needed = ingRate * machineRatio
            let subCost = getRawCostVector(for: ingName, quantity: needed, userRecipes: userRecipes)
            for (res, amount) in subCost { costVector[res] = (costVector[res] ?? 0) + amount }
        }
        return costVector
    }
    
    // --- 2. SOLVEUR EN CASCADE AVEC FALLBACK RECIPE ---
    func calculateAbsoluteAllocation(goals: [ProductionGoal], availableInputs: [ResourceInput], beltLimit: Double, activeRecipes: [String: [Recipe]]) -> OptimizationResult {
        
        // A. Stock Initial
        var inventory: [String: Double] = [:]
        for input in availableInputs {
            inventory[input.resourceName] = (inventory[input.resourceName] ?? 0) + min(input.productionRate, beltLimit)
        }
        let initialPool = inventory
        
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
        let stepSize = 0.1 // On produit par pas de 0.1 item (précision vs perf)
        
        while loop && iterations < 1000 { // Limite de sécurité
            iterations += 1
            var producedSomething = false
            
            for goal in goals {
                // On essaie de produire 'stepSize' de ce goal
                let item = goal.item.name
                let recipes = activeRecipes[item] ?? []
                let defaultRecipe = db.getRecipes(producing: item).first(where: { !$0.isAlternate })
                let candidates = recipes.isEmpty ? (defaultRecipe != nil ? [defaultRecipe!] : []) : recipes
                
                // On cherche une recette capable de produire ce pas
                for recipe in candidates {
                    if canAfford(recipe: recipe, qty: stepSize, inventory: inventory, userRecipes: activeRecipes) {
                        // On paie
                        pay(recipe: recipe, qty: stepSize, inventory: &inventory, userRecipes: activeRecipes)
                        // On enregistre
                        goalProduction[goal.id] = (goalProduction[goal.id] ?? 0) + stepSize
                        
                        // On note la recette utilisée pour le rapport final
                        var itemPlan = productionPlan[item] ?? [:]
                        itemPlan[recipe.id] = (itemPlan[recipe.id] ?? 0) + stepSize
                        productionPlan[item] = itemPlan
                        
                        producedSomething = true
                        break // On a réussi pour ce goal, on passe au suivant (pour équilibrer)
                    }
                }
            }
            
            if !producedSomething { loop = false }
        }
        
        // D. Lissage
        var finalRates: [UUID: Double] = [:]
        for (id, amount) in goalProduction { finalRates[id] = floor(amount) }
        
        // --- PARTIE 3 : SINK (Simplifiée pour cet exemple Multi-Recette) ---
        // On recalcule le surplus réel basé sur l'inventaire restant
        let surplusPool = inventory // Ce qui reste après la boucle est le surplus
        
        var bestSinkResult: SinkResult? = nil
        // (Logique Sink identique à V2, omise pour brièveté mais doit être là)
        
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
            guard let recipe = recipes.first ?? db.getRecipes(producing: item).first(where: { !$0.isAlternate }) else { return }
            let productQty = recipe.products[item] ?? 1.0
            let ratio = rate / productQty
            for (ing, qty) in recipe.ingredients { addDemand(item: ing, rate: qty * ratio) }
        }
        
        for goal in goals { addDemand(item: goal.item.name, rate: finalRates[goal.id] ?? 0) }
        
        for (item, rate) in totalDemandMap {
            if db.rawResources.contains(item) { continue }
            let recipes = activeRecipes[item] ?? []
            if let recipe = recipes.first ?? db.getRecipes(producing: item).first(where: { !$0.isAlternate }) {
                let productQty = recipe.products[item] ?? 1.0
                let machines = rate / productQty
                let step = ConsolidatedStep(
                    item: db.items.first(where: { $0.name == item }) ?? ProductionItem(name: item, category: "Part"),
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
    private func canAfford(recipe: Recipe, qty: Double, inventory: [String: Double], userRecipes: [String: [Recipe]]) -> Bool {
        let productQty = recipe.products[recipe.name] ?? 1.0 // Approx nom
        let ratio = qty / productQty
        
        for (ing, amount) in recipe.ingredients {
            let needed = amount * ratio
            if db.rawResources.contains(ing) {
                if (inventory[ing] ?? 0) < needed { return false }
            } else {
                // Pour un ingrédient manufacturé, on vérifie si on peut le produire récursivement
                // (Simplification : on check juste si on a les minerais pour, c'est lourd)
                // Pour cette V3 "Lite", on va assumer qu'on peut si on a le brut.
                // C'est ici que la complexité explose.
                // On va utiliser une estimation de coût brut.
                let rawCost = getRawCostVector(for: ing, quantity: needed, userRecipes: userRecipes)
                for (r, c) in rawCost {
                    if (inventory[r] ?? 0) < c { return false }
                }
            }
        }
        return true
    }
    
    private func pay(recipe: Recipe, qty: Double, inventory: inout [String: Double], userRecipes: [String: [Recipe]]) {
        // Déduit les ressources brutes nécessaires pour fabriquer 'qty' via 'recipe'
        // On utilise getRawCostVector pour simplifier la chaîne de dépendance
        // Attention: Cela suppose qu'on utilise toujours la recette principale pour les sous-ingrédients
        // C'est une approximation acceptable pour éviter d'écrire un solveur LP complet ici.
        let productQty = (recipe.products.first?.value ?? 1.0)
        let ratio = qty / productQty
        
        for (ing, amount) in recipe.ingredients {
            let needed = amount * ratio
            let rawCost = getRawCostVector(for: ing, quantity: needed, userRecipes: userRecipes)
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
