import Foundation

class ProductionEngine {
    let db = FICSITDatabase.shared
    
    // Résultat Complexe : Plan de production + Info Sink
    struct OptimizationResult {
        let steps: [ConsolidatedStep]
        let sinkReport: SinkResult?
    }
    
    // --- PARTIE 1 : MOTEUR DE COÛTS UNITAIRES ---
    
    // Calcule de quoi on a besoin (Brut) pour faire 1 item
    private func getRawCostVector(for itemName: String, quantity: Double, userRecipes: [String: [Recipe]]) -> [String: Double] {
        var costVector: [String: Double] = [:]
        
        // Base case : C'est une ressource brute
        if db.rawResources.contains(itemName) {
            return [itemName: quantity]
        }
        
        // Trouver la recette active
        let recipes = userRecipes[itemName] ?? []
        // Priorité : Recette utilisateur > Recette Standard
        guard let recipe = recipes.first ?? db.getRecipes(producing: itemName).first(where: { !$0.isAlternate }) else {
            return [:]
        }
        
        let productQty = recipe.products[itemName] ?? 1.0
        let machineRatio = quantity / productQty
        
        for (ingName, ingRate) in recipe.ingredients {
            let needed = ingRate * machineRatio
            let subCost = getRawCostVector(for: ingName, quantity: needed, userRecipes: userRecipes)
            
            // Fusion des vecteurs
            for (res, amount) in subCost {
                costVector[res] = (costVector[res] ?? 0) + amount
            }
        }
        
        return costVector
    }
    
    // --- PARTIE 2 : SOLVEUR D'ALLOCATION & SINK ---
    
    func calculateAbsoluteAllocation(goals: [ProductionGoal], availableInputs: [ResourceInput], beltLimit: Double, activeRecipes: [String: [Recipe]]) -> OptimizationResult {
        
        // 1. Initialiser le Pool de Ressources (R)
        var resourcePool: [String: Double] = [:]
        for input in availableInputs {
            // Clamp par la vitesse de tapis (Input max possible)
            let realInput = min(input.productionRate, beltLimit)
            resourcePool[input.resourceName] = (resourcePool[input.resourceName] ?? 0) + realInput
        }
        
        // Sauvegarde du Pool Initial pour calcul du surplus plus tard
        let initialPool = resourcePool
        
        // 2. Calculer le Coût Unitaire pour chaque Goal
        var goalCosts: [UUID: [String: Double]] = [:]
        for goal in goals {
            goalCosts[goal.id] = getRawCostVector(for: goal.item.name, quantity: 1.0, userRecipes: activeRecipes)
        }
        
        // 3. Boucle d'Allocation (Round-Robin simple mais robuste)
        // On augmente la production tant qu'on peut
        var goalProduction: [UUID: Double] = [:] // Combien on produit de chaque
        for goal in goals { goalProduction[goal.id] = 0 }
        
        // On fait une simulation "Continue" pour trouver le max théorique (Float)
        // Méthode : On cherche le facteur limitant pour l'ensemble du bundle
        // (Note: Pour une vraie allocation indépendante, il faudrait un algo plus complexe,
        // ici on va maximiser le bundle défini par les ratios utilisateur, car c'est ce qu'il a demandé dans l'input)
        
        // Etape A : Calcul du coût d'un "Bundle" (L'ensemble des goals respectant le ratio)
        var bundleCost: [String: Double] = [:]
        for goal in goals {
            let unitCost = goalCosts[goal.id] ?? [:]
            for (res, qty) in unitCost {
                bundleCost[res] = (bundleCost[res] ?? 0) + (qty * goal.ratio)
            }
        }
        
        // Etape B : Trouver le Multiplicateur Max (Théorique)
        var maxMultiplier: Double = Double.greatestFiniteMagnitude
        for (res, costPerBundle) in bundleCost {
            if costPerBundle > 0 {
                let available = resourcePool[res] ?? 0
                let potential = available / costPerBundle
                if potential < maxMultiplier { maxMultiplier = potential }
            }
        }
        
        if maxMultiplier == Double.greatestFiniteMagnitude { maxMultiplier = 0 }
        
        // Etape C : LISSAGE (La règle de l'entier)
        // On ne veut pas 10.2 machines. On veut un chiffre rond pour la production principale.
        // On arrondit le multiplicateur à l'entier inférieur (ex: 10.7 -> 10.0)
        // SAUF si c'est < 1 (on garde 0.x pour ne pas avoir 0)
        let safeMultiplier = maxMultiplier >= 1.0 ? floor(maxMultiplier) : maxMultiplier
        
        // Calcul des taux finaux validés
        var finalRates: [UUID: Double] = [:]
        for goal in goals {
            finalRates[goal.id] = safeMultiplier * goal.ratio
        }
        
        // --- PARTIE 3 : VALORISATION DU SURPLUS (SINK) ---
        
        // Calculer ce qu'on a CONSOMMÉ avec ce safeMultiplier
        var consumedResources: [String: Double] = [:]
        for (res, cost) in bundleCost {
            consumedResources[res] = cost * safeMultiplier
        }
        
        // Calculer le SURPLUS (Ce qui reste dans le pool)
        var surplusPool: [String: Double] = [:]
        for (res, total) in initialPool {
            let used = consumedResources[res] ?? 0
            let left = total - used
            if left > 0.1 { // Seuil de tolérance
                surplusPool[res] = left
            }
        }
        
        // Trouver le MEILLEUR item à faire avec ce surplus
        var bestSinkResult: SinkResult? = nil
        
        // On teste tous les items manufacturés qui ont une valeur Sink
        let sinkableItems = db.items.filter { $0.category == "Part" && $0.sinkValue > 0 }
        
        for item in sinkableItems {
            // Quel est le coût pour 1 de cet item ?
            let itemCost = getRawCostVector(for: item.name, quantity: 1.0, userRecipes: activeRecipes)
            
            // Combien je peux en faire avec le surplus ?
            var maxSinkableAmount: Double = Double.greatestFiniteMagnitude
            
            for (res, cost) in itemCost {
                if cost > 0 {
                    let available = surplusPool[res] ?? 0
                    let potential = available / cost
                    if potential < maxSinkableAmount { maxSinkableAmount = potential }
                }
            }
            
            // Si on peut en faire un peu (ex: > 0.1/min)
            if maxSinkableAmount > 0.1 && maxSinkableAmount != Double.greatestFiniteMagnitude {
                let totalPoints = Int(maxSinkableAmount * Double(item.sinkValue))
                
                if totalPoints > (bestSinkResult?.totalPoints ?? 0) {
                    bestSinkResult = SinkResult(
                        bestItem: item,
                        producedAmount: maxSinkableAmount,
                        totalPoints: totalPoints
                    )
                }
            }
        }
        
        // --- PARTIE 4 : GÉNÉRATION DU PLAN CONSOLIDÉ ---
        // On génère le plan pour la production PRINCIPALE + la production SINK
        
        // 1. Dictionnaire de demande globale
        var totalDemandMap: [String: Double] = [:]
        
        // Ajout Production Principale
        func addDemand(item: String, rate: Double) {
            totalDemandMap[item] = (totalDemandMap[item] ?? 0) + rate
            if db.rawResources.contains(item) { return }
            
            // Trouver recette (avec priorité user)
            let recipes = activeRecipes[item] ?? []
            guard let recipe = recipes.first ?? db.getRecipes(producing: item).first(where: { !$0.isAlternate }) else { return }
            
            let productQty = recipe.products[item] ?? 1.0
            let ratio = rate / productQty
            for (ing, qty) in recipe.ingredients {
                addDemand(item: ing, rate: qty * ratio)
            }
        }
        
        // On injecte les objectifs principaux
        for goal in goals {
            addDemand(item: goal.item.name, rate: finalRates[goal.id] ?? 0)
        }
        
        // On injecte l'objectif Sink (si existant)
        if let sink = bestSinkResult {
            addDemand(item: sink.bestItem.name, rate: sink.producedAmount)
        }
        
        // 2. Conversion en Steps
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
        
        return OptimizationResult(
            steps: steps.sorted { $0.buildingName < $1.buildingName },
            sinkReport: bestSinkResult
        )
    }
    
    // Power (inchangé)
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
