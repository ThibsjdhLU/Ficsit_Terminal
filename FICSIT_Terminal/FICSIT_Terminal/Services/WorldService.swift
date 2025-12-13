import Foundation
import Combine

class WorldService: ObservableObject {
    static let shared = WorldService()

    @Published var world: World

    private let fileManager = FileManager.default
    private let worldFileName = "ficsit_world.json"
    private let lastActiveFactoryKey = "lastActiveFactoryID"

    private var documentsDirectory: URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access documents directory")
        }
        return url
    }

    init() {
        self.world = World(factories: [])
        self.loadWorld()
    }

    // MARK: - PERSISTENCE

    func saveWorld() {
        let fileURL = documentsDirectory.appendingPathComponent(worldFileName)
        do {
            let data = try JSONEncoder().encode(world)
            try data.write(to: fileURL)
            print("World saved successfully to \(fileURL.path)")
        } catch {
            print("Error saving world: \(error)")
        }
    }

    func loadWorld() {
        let fileURL = documentsDirectory.appendingPathComponent(worldFileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let loadedWorld = try JSONDecoder().decode(World.self, from: data)
                self.world = loadedWorld
            } catch {
                print("Error loading world: \(error)")
                // En cas d'erreur critique, on garde un monde vide mais on ne l'écrase pas tout de suite
            }
        } else {
            // Premier lancement ou fichier manquant : on migre les anciens fichiers si présents
            migrateLegacyProjects()
        }
    }

    // Migration des anciens fichiers ProjectData individuels vers le World unique
    private func migrateLegacyProjects() {
        print("Migrating legacy projects...")
        var migratedFactories: [Factory] = []
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            for url in fileURLs where url.pathExtension == "json" && url.lastPathComponent != worldFileName {
                if let data = try? Data(contentsOf: url),
                   let project = try? JSONDecoder().decode(ProjectData.self, from: data) {
                    migratedFactories.append(project)
                }
            }
        } catch {
            print("Error reading legacy files: \(error)")
        }

        if !migratedFactories.isEmpty {
            self.world = World(factories: migratedFactories.sorted { $0.date > $1.date })
            saveWorld()
            print("Migration complete. \(migratedFactories.count) factories imported.")
        }
    }

    // MARK: - FACTORY MANAGEMENT

    func addFactory(_ factory: Factory) {
        world.factories.append(factory)
        saveWorld()
    }

    func updateFactory(_ factory: Factory) {
        if let index = world.factories.firstIndex(where: { $0.id == factory.id }) {
            world.factories[index] = factory
            saveWorld()
        }
    }

    func deleteFactory(_ factory: Factory) {
        world.factories.removeAll { $0.id == factory.id }
        saveWorld()
    }

    func getFactory(id: UUID) -> Factory? {
        return world.factories.first(where: { $0.id == id })
    }

    // MARK: - STATE RESTORATION

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
