import Foundation
import Combine
import SwiftUI

actor BlueprintStorage {
    private let filename = "ficsit_blueprints.json"

    func load() -> [Blueprint] {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename),
              let data = try? Data(contentsOf: url) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Blueprint].self, from: data)
        } catch {
            print("Error decoding blueprints: \(error)")
            return []
        }
    }

    func save(_ blueprints: [Blueprint]) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename) else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(blueprints)
            try data.write(to: url)
        } catch {
            print("Error encoding blueprints: \(error)")
        }
    }
}

@MainActor
class BlueprintService: ObservableObject {
    static let shared = BlueprintService()

    @Published var blueprints: [Blueprint] = []
    private let storage = BlueprintStorage()

    init() {
        Task {
            self.blueprints = await storage.load()
        }
    }

    func saveBlueprint(from factory: Factory, name: String, description: String) {
        let newBlueprint = Blueprint(
            name: name,
            description: description,
            inputs: factory.inputs,
            goals: factory.goals,
            activeRecipes: factory.activeRecipes,
            iconName: factory.goals.first?.item.iconName ?? "doc.text.fill"
        )

        blueprints.append(newBlueprint)
        saveToDisk()
    }

    func add(_ blueprint: Blueprint) {
        blueprints.append(blueprint)
        saveToDisk()
    }

    func delete(_ blueprint: Blueprint) {
        blueprints.removeAll { $0.id == blueprint.id }
        saveToDisk()
    }

    private func saveToDisk() {
        let currentBlueprints = self.blueprints
        Task {
            await storage.save(currentBlueprints)
        }
    }
}
