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

// --- UPDATED RESOURCE INPUT FOR LOGISTICS ---
enum InputSourceType: Codable, Hashable {
    case node(purity: NodePurity, miner: MinerLevel)
    case factory(id: UUID) // Import depuis une autre usine
}

struct ResourceInput: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var resourceName: String

    // Nouveau système de source
    var sourceType: InputSourceType

    // Taux personnalisé (pour les imports résolus ou overrides temporaires)
    // Optionnel pour ne pas polluer le JSON si non utilisé, mais on le rend Codable pour persistance si besoin
    var customRate: Double? = nil

    // --- COMPATIBILITÉ UI & LEGACY ---

    var purity: NodePurity {
        get {
            if case .node(let p, _) = sourceType { return p }
            return .normal
        }
        set {
            if case .node(_, let m) = sourceType { sourceType = .node(purity: newValue, miner: m) }
            else { sourceType = .node(purity: newValue, miner: .mk1) } // Fallback si on édite un import comme un node
        }
    }

    var miner: MinerLevel {
        get {
            if case .node(_, let m) = sourceType { return m }
            return .mk1
        }
        set {
            if case .node(let p, _) = sourceType { sourceType = .node(purity: p, miner: newValue) }
            else { sourceType = .node(purity: .normal, miner: newValue) }
        }
    }

    var factoryID: UUID? {
        if case .factory(let id) = sourceType { return id }
        return nil
    }

    var productionRate: Double {
        if let custom = customRate { return custom }
        switch sourceType {
        case .node(let purity, let miner):
            return miner.baseExtractionRate * purity.multiplier
        case .factory:
            return 0 // Sera remplacé par customRate lors du calcul
        }
    }

    // --- CUSTOM DECODING FOR MIGRATION ---
    enum CodingKeys: String, CodingKey {
        case id, resourceName, sourceType, customRate
        // Legacy keys
        case purity, miner
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Champs communs
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        resourceName = try container.decode(String.self, forKey: .resourceName)
        customRate = try container.decodeIfPresent(Double.self, forKey: .customRate)

        // Tentative de décodage du nouveau format
        if let source = try? container.decodeIfPresent(InputSourceType.self, forKey: .sourceType) {
            sourceType = source
        } else {
            // Fallback : Format Legacy (purity/miner à la racine)
            // On utilise decodeIfPresent pour ne pas crash si les clés manquent (ex: fichier corrompu),
            // mais normalement elles sont là dans l'ancien format.
            let purity = try container.decodeIfPresent(NodePurity.self, forKey: .purity) ?? .normal
            let miner = try container.decodeIfPresent(MinerLevel.self, forKey: .miner) ?? .mk1
            sourceType = .node(purity: purity, miner: miner)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(resourceName, forKey: .resourceName)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encodeIfPresent(customRate, forKey: .customRate)
    }

    // Init standard pour création code
    init(id: UUID = UUID(), resourceName: String, sourceType: InputSourceType, customRate: Double? = nil) {
        self.id = id
        self.resourceName = resourceName
        self.sourceType = sourceType
        self.customRate = customRate
    }
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

// --- TO-DO LIST ITEMS ---
struct ToDoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var category: String? = nil // Ex: "Tier 1", "Logistics"
    var priority: Int = 0 // 0: Normal, 1: High
}

// --- NEW WORLD STRUCTURE ---

struct Factory: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var date: Date
    var inputs: [ResourceInput]
    var goals: [ProductionGoal]
    var activeRecipes: [String: [Recipe]]
    var beltLevel: BeltLevel
    var fuelType: PowerFuel
    var fuelAmount: String

    // Feature Request: To-Do List System
    var toDoList: [ToDoItem]

    enum CodingKeys: String, CodingKey {
        case id, name, date, inputs, goals, activeRecipes, beltLevel, fuelType, fuelAmount, toDoList
    }

    // Initializer
    init(id: UUID = UUID(), name: String, date: Date, inputs: [ResourceInput], goals: [ProductionGoal], activeRecipes: [String: [Recipe]], beltLevel: BeltLevel, fuelType: PowerFuel, fuelAmount: String, toDoList: [ToDoItem] = []) {
        self.id = id
        self.name = name
        self.date = date
        self.inputs = inputs
        self.goals = goals
        self.activeRecipes = activeRecipes
        self.beltLevel = beltLevel
        self.fuelType = fuelType
        self.fuelAmount = fuelAmount
        self.toDoList = toDoList
    }

    // Helper pour initialiser vide
    static func empty() -> Factory {
        Factory(name: "New Factory", date: Date(), inputs: [], goals: [], activeRecipes: [:], beltLevel: .mk3, fuelType: .coal, fuelAmount: "0", toDoList: [])
    }

    // Custom decoding to handle missing toDoList in old JSONs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        inputs = try container.decode([ResourceInput].self, forKey: .inputs)
        goals = try container.decode([ProductionGoal].self, forKey: .goals)
        activeRecipes = try container.decode([String: [Recipe]].self, forKey: .activeRecipes)
        beltLevel = try container.decode(BeltLevel.self, forKey: .beltLevel)
        fuelType = try container.decode(PowerFuel.self, forKey: .fuelType)
        fuelAmount = try container.decode(String.self, forKey: .fuelAmount)
        // Fallback for missing toDoList
        toDoList = try container.decodeIfPresent([ToDoItem].self, forKey: .toDoList) ?? []
    }

    // Custom encoding is not strictly necessary as synthesized one works, but for symmetry/safety:
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(date, forKey: .date)
        try container.encode(inputs, forKey: .inputs)
        try container.encode(goals, forKey: .goals)
        try container.encode(activeRecipes, forKey: .activeRecipes)
        try container.encode(beltLevel, forKey: .beltLevel)
        try container.encode(fuelType, forKey: .fuelType)
        try container.encode(fuelAmount, forKey: .fuelAmount)
        try container.encode(toDoList, forKey: .toDoList)
    }
}

struct World: Codable {
    var factories: [Factory]

    // Le monde contient toutes les usines
}

// --- ALIAS FOR COMPATIBILITY ---
// Pour éviter de casser tout le code existant qui référence ProjectData
typealias ProjectData = Factory

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
    static let defaultStepSize: Double = 1.0
    static let maxIterations: Int = 2000
    static let maxDepthIterations: Int = 10
    static let cacheTimeout: TimeInterval = 300
}

struct GraphConfig {
    static let columnWidth: CGFloat = 350
    static let rowHeight: CGFloat = 200
    static let gridStep: CGFloat = 40
}
