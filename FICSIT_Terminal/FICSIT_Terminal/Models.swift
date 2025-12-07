import Foundation
import SwiftUI

// MARK: - COLORS
extension Color {
    static let ficsitOrange = Color(red: 250/255, green: 149/255, blue: 73/255)
    static let ficsitDark = Color(red: 32/255, green: 33/255, blue: 37/255)
    static let ficsitGray = Color(red: 95/255, green: 102/255, blue: 113/255)
}

// MARK: - ENUMS
enum NodePurity: String, CaseIterable, Codable, Identifiable {
    case impure, normal, pure
    var id: String { self.rawValue }
    var multiplier: Double {
        switch self { case .impure: return 0.5; case .normal: return 1.0; case .pure: return 2.0 }
    }
}

enum MinerLevel: String, CaseIterable, Codable, Identifiable {
    case mk1, mk2, mk3
    var id: String { self.rawValue }
    var baseExtractionRate: Double {
        switch self { case .mk1: return 60; case .mk2: return 120; case .mk3: return 240 }
    }
}

enum BeltLevel: String, CaseIterable, Codable, Identifiable {
    case mk1, mk2, mk3, mk4, mk5
    var id: String { self.rawValue }
    var speed: Double {
        switch self { case .mk1: return 60; case .mk2: return 120; case .mk3: return 270; case .mk4: return 480; case .mk5: return 780 }
    }
}

enum PowerFuel: String, CaseIterable, Identifiable, Codable {
    case coal = "Coal", fuel = "Fuel", turbofuel = "Turbofuel"
    var id: String { self.rawValue }
    var energyValue: Double { switch self { case .coal: return 300; case .fuel: return 750; case .turbofuel: return 2000 } }
    var burnTime: Double { switch self { case .coal: return 4.0; case .fuel: return 5.0; case .turbofuel: return 13.333 } }
    var generatorType: String { switch self { case .coal: return "Coal Generator"; default: return "Fuel Generator" } }
}

// MARK: - DATA STRUCTURES
struct ResourceInput: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var resourceName: String
    var purity: NodePurity
    var miner: MinerLevel
    var productionRate: Double { return miner.baseExtractionRate * purity.multiplier }
}

struct ProductionGoal: Identifiable, Hashable, Codable {
    var id = UUID()
    let item: ProductionItem
    var ratio: Double = 1.0
}

struct ProductionItem: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    let name: String
    let category: String
    var sinkValue: Int = 0

    var localizedName: String {
        Localization.translate(name)
    }
}

struct BuildingDimensions: Codable {
    let width: Double
    let length: Double
    let height: Double
}

enum PortType: String, Codable {
    case input
    case output
}

struct BuildingPort: Codable {
    let id: String
    let type: PortType
    let x: Double
    let y: Double
    let z: Double
}

struct Building: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let powerConsumption: Double
    let buildCost: [String: Int]
    var dimensions: BuildingDimensions?
    var ports: [BuildingPort]?

    var localizedName: String {
        Localization.translate(name)
    }
}

struct Recipe: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let machine: Building
    let ingredients: [String: Double]
    let products: [String: Double]
    let isAlternate: Bool

    var localizedName: String {
        Localization.translate(name)
    }
}

// Résultats
struct ConsolidatedStep: Identifiable {
    let id = UUID()
    let item: ProductionItem
    let totalRate: Double
    let machineCount: Double
    let recipe: Recipe?
    let powerUsage: Double
    let buildingName: String
}

struct PowerResult {
    let fuel: PowerFuel
    let generators: Double
    let totalMW: Double
    let waterNeeded: Double
    let waterExtractors: Double
}

struct SinkResult {
    let bestItem: ProductionItem
    let producedAmount: Double
    let totalPoints: Int
}

struct ShoppingItem: Identifiable {
    let id = UUID()
    let item: ProductionItem
    let count: Int
}

struct ProjectData: Codable, Identifiable {
    var id = UUID()
    var name: String
    var date: Date
    var inputs: [ResourceInput]
    var goals: [ProductionGoal]
    var activeRecipes: [String: [Recipe]]
    var beltLevel: BeltLevel
    var fuelType: PowerFuel
    var fuelAmount: String
}

// MARK: - GRAPH MODELS (MODIFIÉ)

// Nouveau : Type de noeud pour l'affichage
enum GraphNodeType {
    case input      // Ressource (Gauche)
    case machine    // Machine (Milieu)
    case output     // Produit Final (Droite)
}

struct GraphNode: Identifiable {
    let id: UUID
    let item: ProductionItem
    let label: String
    let subLabel: String
    let recipeName: String?
    let color: Color
    
    // Nouveau type
    let type: GraphNodeType
    
    var position: CGPoint = .zero
    static let width: CGFloat = 180
    static let height: CGFloat = 90
    
    // Initializer par défaut pour compatibilité
    init(item: ProductionItem, label: String, subLabel: String, recipeName: String?, color: Color, type: GraphNodeType) {
        self.id = UUID()
        self.item = item
        self.label = label
        self.subLabel = subLabel
        self.recipeName = recipeName
        self.color = color
        self.type = type
        self.position = .zero
    }
    
    // Initializer avec ID personnalisé
    init(id: UUID, item: ProductionItem, label: String, subLabel: String, recipeName: String?, color: Color, type: GraphNodeType, position: CGPoint) {
        self.id = id
        self.item = item
        self.label = label
        self.subLabel = subLabel
        self.recipeName = recipeName
        self.color = color
        self.type = type
        self.position = position
    }
}

struct GraphLink: Identifiable {
    let id = UUID()
    let fromNodeID: UUID
    let toNodeID: UUID
    let rate: Double
    let itemName: String
    let color: Color
}

extension ProductionItem {
    var iconName: String {
        return name.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
    }
}

extension PowerFuel {
    var localizedName: String {
        Localization.translate(self.rawValue)
    }
    var localizedGeneratorType: String {
        Localization.translate(self.generatorType)
    }
}

// MARK: - ERROR HANDLING
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
            return "Aucune recette trouvée pour \(Localization.translate(item)). Vérifiez que l'item existe dans la base de données."
        case .insufficientResources(let item, let needed, let available):
            let missing = needed.compactMap { (key, value) -> String? in
                let avail = available[key] ?? 0
                if value > avail {
                    return "\(Localization.translate(key)): besoin \(String(format: "%.1f", value)), disponible \(String(format: "%.1f", avail))"
                }
                return nil
            }
            return "Ressources insuffisantes pour produire \(Localization.translate(item)).\nManquant:\n\(missing.joined(separator: "\n"))"
        case .circularDependency(let items):
            let translatedItems = items.map { Localization.translate($0) }
            return "Dépendance circulaire détectée: \(translatedItems.joined(separator: " → "))"
        case .invalidRecipe(let recipe, let reason):
            return "Recette invalide '\(Localization.translate(recipe))': \(reason)"
        case .invalidResource(let name):
            return "Ressource invalide: \(Localization.translate(name))"
        case .invalidRate(let resource):
            return "Taux de production invalide pour \(Localization.translate(resource))"
        case .invalidGoal(let item):
            return "Objectif invalide: \(Localization.translate(item))"
        case .calculationTimeout:
            return "Le calcul a pris trop de temps (\(ProductionConfig.maxIterations) itérations). Cela peut indiquer des ressources insuffisantes ou un problème de configuration. Essayez de réduire le nombre d'objectifs ou d'ajouter plus de ressources."
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

// MARK: - CONFIGURATION
struct ProductionConfig {
    static let defaultStepSize: Double = 1.0 // Augmenté de 0.1 à 1.0 pour améliorer les performances
    static let maxIterations: Int = 2000 // Augmenté pour permettre plus d'itérations si nécessaire
    static let maxDepthIterations: Int = 10
    static let cacheTimeout: TimeInterval = 300 // 5 minutes
}

struct GraphConfig {
    static let columnWidth: CGFloat = 350
    static let rowHeight: CGFloat = 200
    static let gridStep: CGFloat = 40
}
