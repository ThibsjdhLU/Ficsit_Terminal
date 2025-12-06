//
//  EXEMPLES_AMELIORATIONS.swift
//  Exemples de code pour les améliorations prioritaires
//

import Foundation
import SwiftUI

// ============================================================================
// 1. MEMOIZATION POUR getRawCostVector
// ============================================================================

class OptimizedProductionEngine {
    let db = FICSITDatabase.shared
    
    // Cache avec invalidation intelligente
    private var costCache: [String: [String: Double]] = [:]
    private var cacheTimestamp: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Clé de cache basée sur l'item et les recettes actives
    private func cacheKey(for itemName: String, userRecipes: [String: [Recipe]]) -> String {
        let recipeKeys = userRecipes.keys.sorted().joined(separator: ",")
        return "\(itemName)|\(recipeKeys)"
    }
    
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
        
        // Trouver la recette
        let recipes = userRecipes[itemName] ?? []
        guard let recipe = recipes.first ?? db.getRecipes(producing: itemName).first(where: { !$0.isAlternate }) else {
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
    
    // Invalider le cache quand les recettes changent
    func invalidateCache() {
        costCache.removeAll()
        cacheTimestamp.removeAll()
    }
}

// ============================================================================
// 2. GESTION D'ERREURS COMPLÈTE
// ============================================================================

enum ProductionError: LocalizedError {
    case noRecipeFound(item: String)
    case insufficientResources(item: String, needed: [String: Double], available: [String: Double])
    case circularDependency(items: [String])
    case invalidRecipe(recipe: String, reason: String)
    case invalidResource(name: String)
    case invalidRate(resource: String)
    case invalidGoal(item: String)
    case calculationTimeout
    case invalidInput(message: String)
    
    var errorDescription: String? {
        switch self {
        case .noRecipeFound(let item):
            return "Aucune recette trouvée pour \(item). Vérifiez que l'item existe dans la base de données."
        case .insufficientResources(let item, let needed, let available):
            let missing = needed.compactMap { (key, value) -> String? in
                let avail = available[key] ?? 0
                if value > avail {
                    return "\(key): besoin \(String(format: "%.1f", value)), disponible \(String(format: "%.1f", avail))"
                }
                return nil
            }
            return "Ressources insuffisantes pour produire \(item).\nManquant:\n\(missing.joined(separator: "\n"))"
        case .circularDependency(let items):
            return "Dépendance circulaire détectée: \(items.joined(separator: " → "))"
        case .invalidRecipe(let recipe, let reason):
            return "Recette invalide '\(recipe)': \(reason)"
        case .invalidResource(let name):
            return "Ressource invalide: \(name)"
        case .invalidRate(let resource):
            return "Taux de production invalide pour \(resource)"
        case .invalidGoal(let item):
            return "Objectif invalide: \(item)"
        case .calculationTimeout:
            return "Le calcul a pris trop de temps. Essayez de réduire le nombre d'objectifs ou de ressources."
        case .invalidInput(let message):
            return "Données d'entrée invalides: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noRecipeFound:
            return "Vérifiez que vous avez débloqué les recettes nécessaires dans le M.A.M."
        case .insufficientResources:
            return "Ajoutez plus de nœuds de ressources ou réduisez vos objectifs de production."
        case .circularDependency:
            return "Vérifiez vos recettes actives. Une recette ne peut pas dépendre d'elle-même."
        default:
            return nil
        }
    }
}

// ============================================================================
// 3. VALIDATION DES DONNÉES
// ============================================================================

struct InputValidator {
    let db: FICSITDatabase
    
    func validateInputs(_ inputs: [ResourceInput]) throws {
        for input in inputs {
            guard db.rawResources.contains(input.resourceName) else {
                throw ProductionError.invalidResource(name: input.resourceName)
            }
            guard input.productionRate > 0 else {
                throw ProductionError.invalidRate(resource: input.resourceName)
            }
            guard input.productionRate <= 240 * 2.0 else { // Mk3 Pure max
                throw ProductionError.invalidRate(resource: input.resourceName)
            }
        }
    }
    
    func validateGoals(_ goals: [ProductionGoal]) throws {
        guard !goals.isEmpty else {
            throw ProductionError.invalidInput(message: "Au moins un objectif est requis")
        }
        
        for goal in goals {
            guard db.items.contains(where: { $0.name == goal.item.name }) else {
                throw ProductionError.invalidGoal(item: goal.item.name)
            }
            guard goal.ratio > 0 else {
                throw ProductionError.invalidInput(message: "Le ratio doit être > 0 pour \(goal.item.name)")
            }
        }
    }
    
    func validateRecipes(_ activeRecipes: [String: [Recipe]]) throws {
        for (itemName, recipes) in activeRecipes {
            for recipe in recipes {
                guard recipe.products.keys.contains(itemName) else {
                    throw ProductionError.invalidRecipe(
                        recipe: recipe.name,
                        reason: "Ne produit pas \(itemName)"
                    )
                }
            }
        }
    }
}

// ============================================================================
// 4. CALCUL ASYNCHRONE AVEC PROGRESSION
// ============================================================================

class AsyncCalculatorViewModel: ObservableObject {
    @Published var calculationProgress: Double = 0.0
    @Published var calculationStatus: String = ""
    @Published var isCalculating: Bool = false
    @Published var lastError: ProductionError?
    
    private var calculationTask: Task<Void, Never>?
    private let engine = OptimizedProductionEngine()
    private let validator = InputValidator(db: FICSITDatabase.shared)
    
    func maximizeProduction(
        goals: [ProductionGoal],
        inputs: [ResourceInput],
        beltLimit: Double,
        activeRecipes: [String: [Recipe]]
    ) async throws -> OptimizationResult {
        
        // Annuler le calcul précédent
        calculationTask?.cancel()
        
        return try await withTaskCancellationHandler {
            // Validation
            try validator.validateInputs(inputs)
            try validator.validateGoals(goals)
            try validator.validateRecipes(activeRecipes)
            
            await MainActor.run {
                isCalculating = true
                calculationProgress = 0.0
                calculationStatus = "Validation..."
                lastError = nil
            }
            
            // Calcul des coûts
            await MainActor.run {
                calculationProgress = 0.2
                calculationStatus = "Calcul des coûts..."
            }
            
            // Simulation de production (avec progression)
            await MainActor.run {
                calculationProgress = 0.5
                calculationStatus = "Optimisation de la production..."
            }
            
            // Génération des étapes
            await MainActor.run {
                calculationProgress = 0.8
                calculationStatus = "Génération du plan..."
            }
            
            // Résultat final
            await MainActor.run {
                calculationProgress = 1.0
                calculationStatus = "Terminé"
                isCalculating = false
            }
            
            // Ici, le vrai calcul serait fait
            // return try engine.calculate(...)
            throw ProductionError.invalidInput(message: "Exemple - à implémenter")
            
        } onCancel: {
            await MainActor.run {
                isCalculating = false
                calculationStatus = "Annulé"
            }
        }
    }
    
    func cancelCalculation() {
        calculationTask?.cancel()
    }
}

// ============================================================================
// 5. INDEXATION DE LA BASE DE DONNÉES
// ============================================================================

extension FICSITDatabase {
    private var _recipeIndex: [String: [Recipe]]?
    private var _itemIndex: [String: ProductionItem]?
    
    var recipeIndex: [String: [Recipe]] {
        if _recipeIndex == nil {
            buildIndexes()
        }
        return _recipeIndex!
    }
    
    var itemIndex: [String: ProductionItem] {
        if _itemIndex == nil {
            buildIndexes()
        }
        return _itemIndex!
    }
    
    private func buildIndexes() {
        var recipeIdx: [String: [Recipe]] = [:]
        var itemIdx: [String: ProductionItem] = [:]
        
        // Index des recettes par produit
        for recipe in recipes {
            for productName in recipe.products.keys {
                recipeIdx[productName, default: []].append(recipe)
            }
        }
        
        // Index des items par nom
        for item in items {
            itemIdx[item.name] = item
        }
        
        _recipeIndex = recipeIdx
        _itemIndex = itemIdx
    }
    
    // Version optimisée de getRecipes
    func getRecipesOptimized(producing itemName: String) -> [Recipe] {
        return recipeIndex[itemName] ?? []
    }
    
    func getItemOptimized(named name: String) -> ProductionItem? {
        return itemIndex[name]
    }
}

// ============================================================================
// 6. DÉTECTION DE GOULOTS D'ÉTRANGLEMENT
// ============================================================================

struct Bottleneck {
    let item: String
    let requiredRate: Double
    let availableRate: Double
    let shortfall: Double
    let suggestions: [String]
    let severity: Severity
    
    enum Severity {
        case critical    // Bloque complètement
        case high        // Réduit significativement
        case medium      // Impact modéré
        case low         // Impact mineur
    }
}

class BottleneckDetector {
    let db = FICSITDatabase.shared
    
    func detectBottlenecks(
        goals: [ProductionGoal],
        inputs: [ResourceInput],
        beltLimit: Double,
        activeRecipes: [String: [Recipe]]
    ) -> [Bottleneck] {
        
        var bottlenecks: [Bottleneck] = []
        
        // Calculer les taux requis
        var requiredRates: [String: Double] = [:]
        for goal in goals {
            requiredRates[goal.item.name] = goal.ratio
        }
        
        // Remonter les dépendances
        func calculateRequiredRates(item: String) -> Double {
            if let cached = requiredRates[item] {
                return cached
            }
            
            let recipes = activeRecipes[item] ?? db.getRecipesOptimized(producing: item)
            guard let recipe = recipes.first else { return 0 }
            
            let productQty = recipe.products[item] ?? 1.0
            var totalRequired: Double = 0
            
            // Calculer ce qui est requis pour les items qui dépendent de celui-ci
            // (Simplifié - nécessite un graphe de dépendances inverse)
            
            return totalRequired
        }
        
        // Comparer avec les ressources disponibles
        var availableRates: [String: Double] = [:]
        for input in inputs {
            availableRates[input.resourceName] = min(input.productionRate, beltLimit)
        }
        
        // Détecter les goulots
        for (item, required) in requiredRates {
            let available = availableRates[item] ?? 0
            if required > available {
                let shortfall = required - available
                let severity: Bottleneck.Severity = shortfall > required * 0.5 ? .critical : .high
                
                let suggestions = generateSuggestions(
                    item: item,
                    shortfall: shortfall,
                    inputs: inputs
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
        inputs: [ResourceInput]
    ) -> [String] {
        var suggestions: [String] = []
        
        // Suggestion 1: Ajouter plus de nœuds
        if db.rawResources.contains(item) {
            suggestions.append("Ajouter un nœud de \(item) supplémentaire")
        }
        
        // Suggestion 2: Améliorer la pureté
        if let input = inputs.first(where: { $0.resourceName == item }) {
            if input.purity != .pure {
                suggestions.append("Utiliser un nœud Pur de \(item)")
            }
            if input.miner != .mk3 {
                suggestions.append("Améliorer le foreur à Mk3")
            }
        }
        
        // Suggestion 3: Améliorer les ceintures
        suggestions.append("Vérifier que les ceintures Mk5 sont utilisées")
        
        return suggestions
    }
}

// ============================================================================
// 7. SUGGESTIONS INTELLIGENTES
// ============================================================================

struct Suggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let message: String
    let impact: Impact
    let action: () -> Void
    
    enum SuggestionType {
        case useAlternateRecipe
        case upgradeBelt
        case addResourceNode
        case optimizePower
        case reduceGoals
        case useSink
    }
    
    enum Impact {
        case high, medium, low
    }
}

class SuggestionEngine {
    func generateSuggestions(
        for viewModel: CalculatorViewModel,
        bottlenecks: [Bottleneck]
    ) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        // Suggestion basée sur les goulots
        for bottleneck in bottlenecks {
            if bottleneck.severity == .critical {
                suggestions.append(Suggestion(
                    type: .reduceGoals,
                    title: "Objectifs trop ambitieux",
                    message: "\(bottleneck.item) manque de \(String(format: "%.1f", bottleneck.shortfall))/min",
                    impact: .high,
                    action: {
                        // Action à implémenter
                    }
                ))
            }
        }
        
        // Suggestion pour recettes alternatives
        if viewModel.activeRecipes.isEmpty {
            suggestions.append(Suggestion(
                type: .useAlternateRecipe,
                title: "Recettes alternatives disponibles",
                message: "Certaines recettes alternatives peuvent améliorer l'efficacité",
                impact: .medium,
                action: {
                    // Ouvrir la vue des recettes
                }
            ))
        }
        
        // Suggestion pour le Sink
        if viewModel.sinkResult == nil && !viewModel.consolidatedPlan.isEmpty {
            suggestions.append(Suggestion(
                type: .useSink,
                title: "Surplus disponible",
                message: "Vous avez des ressources en surplus. Envoyez-les au Sink pour des points !",
                impact: .low,
                action: {
                    // Afficher le résultat Sink
                }
            ))
        }
        
        return suggestions.sorted { $0.impact > $1.impact }
    }
}

// ============================================================================
// 8. EXPORT DES RÉSULTATS
// ============================================================================

struct ExportService {
    func exportToCSV(plan: [ConsolidatedStep]) -> String {
        var csv = "Machine,Item,Rate/min,Machines,Power MW\n"
        for step in plan {
            csv += "\(step.buildingName),\(step.item.name),\(step.totalRate),\(step.machineCount),\(step.powerUsage)\n"
        }
        return csv
    }
    
    func exportToJSON(project: ProjectData) -> Data? {
        return try? JSONEncoder().encode(project)
    }
    
    func shareResults(_ results: String) {
        // Utiliser UIActivityViewController pour partager
        // (nécessite une vue SwiftUI)
    }
}

// ============================================================================
// 9. COMPARAISON DE SCÉNARIOS
// ============================================================================

struct ScenarioComparison {
    let scenarios: [ProductionScenario]
    let metrics: [ComparisonMetric]
    
    struct ComparisonMetric {
        let name: String
        let values: [String: Double]
        let bestScenario: String?
    }
}

struct ProductionScenario {
    let name: String
    let inputs: [ResourceInput]
    let goals: [ProductionGoal]
    let activeRecipes: [String: [Recipe]]
    let result: OptimizationResult?
}

class ScenarioComparator {
    func compare(_ scenarios: [ProductionScenario]) -> ScenarioComparison {
        var metrics: [ScenarioComparison.ComparisonMetric] = []
        
        // Métrique: Nombre de machines
        let machineCounts = Dictionary(uniqueKeysWithValues:
            scenarios.map { ($0.name, Double($0.result?.steps.count ?? 0)) }
        )
        metrics.append(ScenarioComparison.ComparisonMetric(
            name: "Nombre de machines",
            values: machineCounts,
            bestScenario: machineCounts.min(by: { $0.value < $1.value })?.key
        ))
        
        // Métrique: Consommation énergétique
        let powerConsumptions = Dictionary(uniqueKeysWithValues:
            scenarios.map { ($0.name, $0.result?.steps.reduce(0) { $0 + $1.powerUsage } ?? 0) }
        )
        metrics.append(ScenarioComparison.ComparisonMetric(
            name: "Consommation (MW)",
            values: powerConsumptions,
            bestScenario: powerConsumptions.min(by: { $0.value < $1.value })?.key
        ))
        
        return ScenarioComparison(scenarios: scenarios, metrics: metrics)
    }
}

