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
    // Propriété critique pour l'algo Sink (Mise à 0 par défaut si absente du JSON)
    var sinkValue: Int = 0
}

struct Building: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let powerConsumption: Double
    let buildCost: [String: Int]
}

struct Recipe: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let machine: Building
    let ingredients: [String: Double]
    let products: [String: Double]
    let isAlternate: Bool
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

// NOUVEAU : Résultat de l'optimisation SINK
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

// Graph
struct GraphNode: Identifiable {
    let id = UUID()
    let item: ProductionItem
    let label: String
    let subLabel: String
    let recipeName: String?
    let color: Color
    var position: CGPoint = .zero
    static let width: CGFloat = 180
    static let height: CGFloat = 90
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
