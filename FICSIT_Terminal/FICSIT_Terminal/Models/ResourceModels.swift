import Foundation

// MARK: - RESOURCE EXTRACTION MODELS

struct MapResourceNodeCount: Identifiable, Sendable {
    let id = UUID()
    let resourceName: String
    let impure: Int
    let normal: Int
    let pure: Int

    // For fluids (Wells are different, but simplifying for now)
    let wells: Int

    // Max theoretical output with Mk3 Miners + 250% Overclock
    // Base Rates: Impure 30, Normal 60, Pure 120
    // Mk3 Miner: x4 -> 120, 240, 480
    // Overclock 250%: x2.5 -> 300, 600, 1200
    // Note: Conveyor Mk5 limit is 780/min, so Pure nodes are capped at 780 without mods.
    func calculateMaxPotential(conveyorLimit: Double = 780.0) -> Double {
        let impureRate = min(30.0 * 4.0 * 2.5, conveyorLimit)
        let normalRate = min(60.0 * 4.0 * 2.5, conveyorLimit)
        let pureRate = min(120.0 * 4.0 * 2.5, conveyorLimit)

        return (Double(impure) * impureRate) +
               (Double(normal) * normalRate) +
               (Double(pure) * pureRate)
    }
}

// Static Database of World Resources (Approximate for Update 8/1.0)
struct WorldResourceDatabase {
    static let resources: [MapResourceNodeCount] = [
        MapResourceNodeCount(resourceName: "Iron Ore", impure: 33, normal: 41, pure: 46, wells: 0),
        MapResourceNodeCount(resourceName: "Copper Ore", impure: 12, normal: 28, pure: 12, wells: 0),
        MapResourceNodeCount(resourceName: "Limestone", impure: 12, normal: 47, pure: 27, wells: 0),
        MapResourceNodeCount(resourceName: "Coal", impure: 6, normal: 29, pure: 15, wells: 0),
        MapResourceNodeCount(resourceName: "Caterium Ore", impure: 0, normal: 8, pure: 8, wells: 0),
        MapResourceNodeCount(resourceName: "Raw Quartz", impure: 0, normal: 11, pure: 5, wells: 0),
        MapResourceNodeCount(resourceName: "Sulfur", impure: 1, normal: 7, pure: 3, wells: 0),
        MapResourceNodeCount(resourceName: "Bauxite", impure: 5, normal: 6, pure: 6, wells: 0),
        MapResourceNodeCount(resourceName: "Uranium", impure: 1, normal: 2, pure: 1, wells: 0),
        MapResourceNodeCount(resourceName: "Oil", impure: 10, normal: 12, pure: 8, wells: 0), // Oil is nodes
        MapResourceNodeCount(resourceName: "Nitrogen Gas", impure: 2, normal: 7, pure: 36, wells: 10), // Gas is wells, simplified
    ]

    static func get(resource: String) -> MapResourceNodeCount? {
        return resources.first { $0.resourceName == resource }
    }
}
