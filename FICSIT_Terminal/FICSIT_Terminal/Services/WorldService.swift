import Foundation
import Combine
import SwiftUI

// MARK: - Protocol

protocol WorldServiceProtocol: AnyObject {
    var world: World { get }
    var worldPublisher: AnyPublisher<World, Never> { get }

    func loadWorld() async
    func saveWorld() async
    func addFactory(_ factory: Factory)
    func updateFactory(_ factory: Factory)
    func deleteFactory(_ factory: Factory)
    func getFactory(id: UUID) -> Factory?
    func getLastActiveFactoryID() -> UUID?
    func setLastActiveFactoryID(_ id: UUID)
}

// MARK: - Actor for I/O

actor WorldStorage {
    private let fileManager = FileManager.default
    private let worldFileName = "ficsit_world.json"

    private var documentsDirectory: URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access documents directory")
        }
        return url
    }

    func save(_ world: World) throws {
        let fileURL = documentsDirectory.appendingPathComponent(worldFileName)
        let data = try JSONEncoder().encode(world)
        try data.write(to: fileURL)
    }

    func load() throws -> World {
        let fileURL = documentsDirectory.appendingPathComponent(worldFileName)
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(World.self, from: data)
    }

    func migrateLegacyProjects() throws -> [Factory] {
        var migratedFactories: [Factory] = []
        let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
        for url in fileURLs where url.pathExtension == "json" && url.lastPathComponent != worldFileName {
            if let data = try? Data(contentsOf: url),
               let project = try? JSONDecoder().decode(Factory.self, from: data) {
                migratedFactories.append(project)
            }
        }
        return migratedFactories
    }

    func fileExists() -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(worldFileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}

// MARK: - Service

@MainActor
class WorldService: ObservableObject, WorldServiceProtocol {

    // Singleton for legacy compatibility, but prefer injection
    static let shared = WorldService()

    @Published private(set) var world: World = World(factories: [])
    @Published var error: Error?

    var worldPublisher: AnyPublisher<World, Never> {
        $world.eraseToAnyPublisher()
    }

    private let storage = WorldStorage()
    private let lastActiveFactoryKey = "lastActiveFactoryID"

    init() {
        // Initial empty state, should call loadWorld() immediately after
        // Note: We cannot await in init, so we start a task or rely on caller
        Task {
            await loadWorld()
        }
    }

    func loadWorld() async {
        do {
            if await storage.fileExists() {
                let loadedWorld = try await storage.load()
                self.world = loadedWorld
            } else {
                // Migration path
                let migrated = try await storage.migrateLegacyProjects()
                if !migrated.isEmpty {
                    self.world = World(factories: migrated.sorted { $0.date > $1.date })
                    await saveWorld()
                }
            }
        } catch {
            print("Craft Error: Failed to load world: \(error)") // Debug log
            self.error = error
        }
    }

    func saveWorld() async {
        do {
            try await storage.save(self.world)
        } catch {
            print("Craft Error: Failed to save world: \(error)") // Debug log
            self.error = error
        }
    }

    // MARK: - CRUD

    func addFactory(_ factory: Factory) {
        world.factories.append(factory)
        triggerSave()
    }

    func updateFactory(_ factory: Factory) {
        if let index = world.factories.firstIndex(where: { $0.id == factory.id }) {
            world.factories[index] = factory
            triggerSave()
        }
    }

    func deleteFactory(_ factory: Factory) {
        world.factories.removeAll { $0.id == factory.id }
        triggerSave()
    }

    func getFactory(id: UUID) -> Factory? {
        world.factories.first(where: { $0.id == id })
    }

    private func triggerSave() {
        Task {
            await saveWorld()
        }
    }

    // MARK: - Preferences

    func getLastActiveFactoryID() -> UUID? {
        if let idString = UserDefaults.standard.string(forKey: lastActiveFactoryKey),
           let uuid = UUID(uuidString: idString) {
            return uuid
        }
        return nil
    }

    func setLastActiveFactoryID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: lastActiveFactoryKey)
    }
}
