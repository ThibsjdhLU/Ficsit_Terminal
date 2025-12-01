import SwiftUI
import Combine

class FICSITDatabase: ObservableObject {
    static let shared = FICSITDatabase()
    
    @Published var items: [ProductionItem] = []
    @Published var recipes: [Recipe] = []
    @Published var buildings: [Building] = []
    
    let rawResources = ["Iron Ore", "Copper Ore", "Limestone", "Coal", "Oil", "Water", "Caterium Ore", "Raw Quartz", "Sulfur", "Bauxite", "Uranium", "Nitrogen Gas"]
    
    init() {
        loadDataFromJSON()
    }
    
    // --- STRUCTURES DE DÉCODAGE (Miroir du JSON) ---
    private struct JSONWrapper: Codable {
        let items: [JSONItem]
        let buildings: [JSONBuilding]
        let recipes: [JSONRecipe]
    }
    
    private struct JSONItem: Codable {
        let name: String
        let category: String
        // Ajout du champ optionnel pour le JSON
        let sinkValue: Int?
    }
    
    private struct JSONBuilding: Codable {
        let name: String
        let type: String
        let powerConsumption: Double
        let buildCost: [String: Int]
    }
    
    private struct JSONRecipe: Codable {
        let name: String
        let machineName: String
        let isAlternate: Bool
        let ingredients: [String: Double]
        let products: [String: Double]
    }
    
    // --- FONCTION DE CHARGEMENT ---
    func loadDataFromJSON() {
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json") else {
            print("❌ ERREUR CRITIQUE : Fichier 'data.json' introuvable dans le Bundle !")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(JSONWrapper.self, from: data)
            
            // 4. Convertir en objets App (Mapping)
            
            // A. ITEMS (Correction Sink Value)
            self.items = decoded.items.map { item in
                ProductionItem(
                    name: item.name,
                    category: item.category,
                    sinkValue: item.sinkValue ?? 0 // Utilise la valeur du JSON ou 0
                )
            }
            
            // B. BUILDINGS
            self.buildings = decoded.buildings.map { b in
                Building(name: b.name, powerConsumption: b.powerConsumption, buildCost: b.buildCost)
            }
            
            // C. RECIPES
            self.recipes = decoded.recipes.compactMap { r in
                guard let machineObj = self.buildings.first(where: { $0.name == r.machineName }) else { return nil }
                return Recipe(name: r.name, machine: machineObj, ingredients: r.ingredients, products: r.products, isAlternate: r.isAlternate)
            }
            
        } catch {
            print("❌ ERREUR DE DÉCODAGE JSON : \(error)")
        }
    }
    
    func getRecipes(producing itemName: String) -> [Recipe] {
        return recipes.filter { $0.products.keys.contains(itemName) }
    }
}
