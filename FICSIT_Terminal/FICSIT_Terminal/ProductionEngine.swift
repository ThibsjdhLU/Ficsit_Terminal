import Foundation

class ProductionEngine {
    let db = FICSITDatabase.shared
    
    struct OptimizationResult {
        let steps: [ConsolidatedStep]
        let sinkReport: SinkResult?
    }
    
    // --- 1. COÛTS UNITAIRES ---
    private func getRawCostVector(for itemName: String, quantity: Double, userRecipes: [String: [Recipe]]) -> [String: Double] {
        var costVector: [String: Double] = [:]
        if db.rawResources.contains(itemName) { return [itemName: quantity] }
        
        let recipes = userRecipes[itemName] ?? []
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
    
    // --- 2. SOLVEUR EN CASCADE (CASCADING BOTTLENECK) ---
    func calculateAbsoluteAllocation(goals: [ProductionGoal], availableInputs: [ResourceInput], beltLimit: Double, activeRecipes: [String: [Recipe]]) -> OptimizationResult {
        
        // A. Stock Initial
        var inventory: [String: Double] = [:]
        for input in availableInputs {
            inventory[input.resourceName] = (inventory[input.resourceName] ?? 0) + min(input.productionRate, beltLimit)
        }
        let initialPool = inventory // Copie pour le Sink plus tard
        
        // B. Coûts unitaires
        var goalCosts: [UUID: [String: Double]] = [:]
        for goal in goals {
            goalCosts[goal.id] = getRawCostVector(for: goal.item.name, quantity: 1.0, userRecipes: activeRecipes)
        }
        
        // C. Boucle de Cascade
        var goalProduction: [UUID: Double] = [:]
        for goal in goals { goalProduction[goal.id] = 0.0 }
        
        // On garde une liste des objectifs "actifs" (ceux qu'on peut encore produire)
        var activeGoalIDs = Set(goals.map { $0.id })
        
        // Sécurité anti-boucle
        var iteration = 0
        while !activeGoalIDs.isEmpty && iteration < 20 {
            iteration += 1
            
            // 1. Calculer la demande combinée pour 1 unité de chaque goal actif
            var combinedCost: [String: Double] = [:]
            for goalID in activeGoalIDs {
                guard let goal = goals.first(where: { $0.id == goalID }) else { continue }
                let uCost = goalCosts[goalID] ?? [:]
                for (res, qty) in uCost {
                    combinedCost[res] = (combinedCost[res] ?? 0) + (qty * goal.ratio)
                }
            }
            
            // 2. Trouver le Multiplicateur Max possible avec l'inventaire actuel
            var maxMultiplier: Double = Double.greatestFiniteMagnitude
            var limitingResource: String? = nil
            
            for (res, costPerBatch) in combinedCost {
                if costPerBatch > 0 {
                    let available = inventory[res] ?? 0
                    let potential = available / costPerBatch
                    if potential < maxMultiplier {
                        maxMultiplier = potential
                        limitingResource = res
                    }
                }
            }
            
            if maxMultiplier == Double.greatestFiniteMagnitude { maxMultiplier = 0 }
            
            // 3. Produire ce "Batch"
            // On applique un arrondi "Safe" si on est proche de l'entier pour éviter les 9.9999
            let stepMultiplier = maxMultiplier
            
            if stepMultiplier > 0.001 {
                for goalID in activeGoalIDs {
                    guard let goal = goals.first(where: { $0.id == goalID }) else { continue }
                    let addedAmount = stepMultiplier * goal.ratio
                    goalProduction[goalID] = (goalProduction[goalID] ?? 0) + addedAmount
                    
                    // Déduire les ressources
                    let uCost = goalCosts[goalID] ?? [:]
                    for (res, qty) in uCost {
                        inventory[res] = (inventory[res] ?? 0) - (qty * addedAmount)
                    }
                }
            } else {
                // Si on ne peut plus rien produire du tout, on arrête
                break
            }
            
            // 4. Désactiver les goals qui dépendent de la ressource limitante
            // (Car cette ressource est vide, ils ne peuvent plus avancer)
            if let limitRes = limitingResource {
                // On retire tous les goals qui ont besoin de cette ressource
                let blockedGoals = activeGoalIDs.filter { id in
                    let cost = goalCosts[id] ?? [:]
                    return (cost[limitRes] ?? 0) > 0
                }
                
                // S'il n'y a aucun goal bloqué (ex: ressource non utilisée ?), on force l'arrêt pour éviter boucle infinie
                if blockedGoals.isEmpty { break }
                
                for bg in blockedGoals {
                    activeGoalIDs.remove(bg)
                }
            } else {
                break // Plus de contrainte, on a tout fini (rare)
            }
        }
        
        // D. Lissage Entier (Optionnel mais propre)
        // On arrondit à l'entier inférieur pour la production finale affichée
        var finalRates: [UUID: Double] = [:]
        for (id, amount) in goalProduction {
            finalRates[id] = floor(amount) // On garde les entiers pour la construction
        }
        
        // --- PARTIE 3 : SINK (SURPLUS) ---
        // On recalcule le coût réel de la prod finale (arrondie) pour voir le vrai surplus
        var usedResources: [String: Double] = [:]
        for goal in goals {
            let rate = finalRates[goal.id] ?? 0
            let uCost = goalCosts[goal.id] ?? [:]
            for (res, qty) in uCost {
                usedResources[res] = (usedResources[res] ?? 0) + (qty * rate)
            }
        }
        
        var surplusPool: [String: Double] = [:]
        for (res, total) in initialPool {
            let used = usedResources[res] ?? 0
            let left = total - used
            if left > 0.1 { surplusPool[res] = left }
        }
        
        // Trouver le meilleur item à broyer
        var bestSinkResult: SinkResult? = nil
        let sinkableItems = db.items.filter { $0.category == "Part" && $0.sinkValue > 0 }
        
        for item in sinkableItems {
            let itemCost = getRawCostVector(for: item.name, quantity: 1.0, userRecipes: activeRecipes)
            var maxSinkable: Double = Double.greatestFiniteMagnitude
            for (res, cost) in itemCost {
                if cost > 0 {
                    let available = surplusPool[res] ?? 0
                    let potential = available / cost
                    if potential < maxSinkable { maxSinkable = potential }
                }
            }
            
            if maxSinkable > 0.1 && maxSinkable != Double.greatestFiniteMagnitude {
                let points = Int(maxSinkable * Double(item.sinkValue))
                if points > (bestSinkResult?.totalPoints ?? 0) {
                    bestSinkResult = SinkResult(bestItem: item, producedAmount: maxSinkable, totalPoints: points)
                }
            }
        }
        
        // --- PARTIE 4 : GÉNÉRATION STEPS ---
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
        
        // Ajout Prod Principale
        for goal in goals { addDemand(item: goal.item.name, rate: finalRates[goal.id] ?? 0) }
        // Ajout Sink
        if let sink = bestSinkResult { addDemand(item: sink.bestItem.name, rate: sink.producedAmount) }
        
        var steps: [ConsolidatedStep] = []
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
    
    func calculatePowerScenario(fuel: PowerFuel, amountAvailable: Double) -> PowerResult {
        let consumptionPerGen = 60.0 / fuel.burnTime
        let numGenerators = amountAvailable / consumptionPerGen
        let mwPerGen: Double = (fuel == .coal) ? 75.0 : 150.0
        let totalMW = numGenerators * mwPerGen
        var waterNeeded: Double = 0; var extractors: Double = 0
        if fuel == .coal { waterNeeded = numGenerators * 45.0; extractors = waterNeeded / 120.0 }
        return PowerResult(fuel: fuel, generators: numGenerators, totalMW: totalMW, waterNeeded: waterNeeded, waterExtractors: extractors)
    }
}
