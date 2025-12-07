import Foundation

struct Bottleneck {
    let item: String
    let requiredRate: Double
    let availableRate: Double
    let shortfall: Double
    let suggestions: [String]
    let severity: Severity
    
    enum Severity: Comparable {
        case critical    // Bloque complètement
        case high        // Réduit significativement
        case medium      // Impact modéré
        case low         // Impact mineur
        
        static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.low, .medium, .high, .critical]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
}

class BottleneckDetector {
    let db = FICSITDatabase.shared
    
    func detectBottlenecks(
        goals: [ProductionGoal],
        inputs: [ResourceInput],
        beltLimit: Double,
        activeRecipes: [String: [Recipe]],
        consolidatedPlan: [ConsolidatedStep]
    ) -> [Bottleneck] {
        
        var bottlenecks: [Bottleneck] = []
        
        // Calculer les taux requis pour chaque item
        var requiredRates: [String: Double] = [:]
        for goal in goals {
            requiredRates[goal.item.name] = (requiredRates[goal.item.name] ?? 0) + goal.ratio
        }
        
        // Remonter les dépendances pour calculer tous les taux requis
        func calculateRequiredRates(item: String, visited: inout Set<String>) {
            guard !visited.contains(item) else { return }
            visited.insert(item)
            
            // Si c'est une ressource brute, on a déjà le taux requis
            if db.rawResources.contains(item) {
                return
            }
            
            // Trouver les recettes qui produisent cet item
            let recipes = activeRecipes[item] ?? db.getRecipesOptimized(producing: item)
            guard let recipe = recipes.first(where: { !$0.isAlternate }) ?? recipes.first else {
                return
            }
            
            // Pour chaque ingrédient, calculer le taux requis
            let productQty = recipe.products[item] ?? 1.0
            guard productQty > 0 else { return }
            
            let itemRequired = requiredRates[item] ?? 0
            let ratio = itemRequired / productQty
            
            for (ing, qty) in recipe.ingredients {
                let ingRequired = qty * ratio
                requiredRates[ing] = (requiredRates[ing] ?? 0) + ingRequired
                calculateRequiredRates(item: ing, visited: &visited)
            }
        }
        
        var visited: Set<String> = []
        for goal in goals {
            calculateRequiredRates(item: goal.item.name, visited: &visited)
        }
        
        // Comparer avec les ressources disponibles
        var availableRates: [String: Double] = [:]
        for input in inputs {
            availableRates[input.resourceName] = (availableRates[input.resourceName] ?? 0) + min(input.productionRate, beltLimit)
        }
        
        // Pour les items manufacturés, utiliser les taux de production réels
        for step in consolidatedPlan {
            availableRates[step.item.name] = step.totalRate
        }
        
        // Détecter les goulots
        for (item, required) in requiredRates {
            let available = availableRates[item] ?? 0
            if required > available {
                let shortfall = required - available
                let percentage = shortfall / required
                
                let severity: Bottleneck.Severity = {
                    if percentage > 0.5 { return .critical }
                    if percentage > 0.3 { return .high }
                    if percentage > 0.1 { return .medium }
                    return .low
                }()
                
                let suggestions = generateSuggestions(
                    item: item,
                    shortfall: shortfall,
                    inputs: inputs,
                    isRawResource: db.rawResources.contains(item)
                )
                
                bottlenecks.append(Bottleneck(
                    item: item,
                    requiredRate: required,
                    availableRate: available,
                    shortfall: shortfall,
                    suggestions: suggestions,
                    severity: severity
                ))
            }
        }
        
        return bottlenecks.sorted { $0.severity > $1.severity }
    }
    
    private func generateSuggestions(
        item: String,
        shortfall: Double,
        inputs: [ResourceInput],
        isRawResource: Bool
    ) -> [String] {
        var suggestions: [String] = []
        
        let localizedItem = Localization.translate(item)

        if isRawResource {
            // Suggestion 1: Ajouter plus de nœuds
            suggestions.append("\(Localization.translate("Add more nodes for")) \(localizedItem)")
            
            // Suggestion 2: Améliorer la pureté
            if let input = inputs.first(where: { $0.resourceName == item }) {
                if input.purity != .pure {
                    suggestions.append("\(Localization.translate("Use a Pure node for")) \(localizedItem)")
                }
                if input.miner != .mk3 {
                    suggestions.append(Localization.translate("Upgrade Miner to Mk3"))
                }
            }
        } else {
            // Pour les items manufacturés
            suggestions.append("\(Localization.translate("Increase production of")) \(localizedItem)")
            suggestions.append(Localization.translate("Check alternate recipes"))
        }
        
        // Suggestion générale
        suggestions.append(Localization.translate("Verify Mk5 belts are used"))
        
        return suggestions
    }
}

