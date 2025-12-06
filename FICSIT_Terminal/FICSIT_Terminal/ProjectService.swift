import Foundation

class ProjectService {
    static let shared = ProjectService()
    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access documents directory")
        }
        return url
    }
    
    func saveProject(_ project: ProjectData) {
        let fileName = "\(project.id.uuidString).json"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(project)
            try data.write(to: fileURL)
        } catch { print("Error saving: \(error)") }
    }
    
    func loadAllProjects() -> [ProjectData] {
        var projects: [ProjectData] = []
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            for url in fileURLs where url.pathExtension == "json" {
                if let data = try? Data(contentsOf: url), let project = try? JSONDecoder().decode(ProjectData.self, from: data) {
                    projects.append(project)
                }
            }
        } catch { print("Error loading: \(error)") }
        return projects.sorted { $0.date > $1.date }
    }
    
    func deleteProject(_ project: ProjectData) {
        let fileName = "\(project.id.uuidString).json"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }
}
