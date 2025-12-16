import Foundation

struct Blueprint: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var createdDate: Date
    var version: String = "1.0"

    // The core of a blueprint is a subset of a Factory's data
    var inputs: [ResourceInput]
    var goals: [ProductionGoal]
    var activeRecipes: [String: [Recipe]]
    var iconName: String // e.g. "blueprint_icon" or "iron_plate"

    // Metadata
    var author: String?
    var tags: [String] = []

    init(id: UUID = UUID(), name: String, description: String, inputs: [ResourceInput], goals: [ProductionGoal], activeRecipes: [String: [Recipe]], iconName: String = "doc.text.fill") {
        self.id = id
        self.name = name
        self.description = description
        self.createdDate = Date()
        self.inputs = inputs
        self.goals = goals
        self.activeRecipes = activeRecipes
        self.iconName = iconName
    }
}
