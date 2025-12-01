import SwiftUI
import Combine

class FICSITDatabase: ObservableObject {
    static let shared = FICSITDatabase()
    
    @Published var items: [ProductionItem] = []
    @Published var recipes: [Recipe] = []
    @Published var buildings: [Building] = []
    
    // On garde les ressources brutes "en dur" pour le picker de l'onglet 1 (plus simple)
    // Mais on pourrait aussi les déduire du JSON si on voulait être puriste.
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
        // 1. Localiser le fichier data.json dans le Bundle de l'app
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json") else {
            print("❌ ERREUR CRITIQUE : Fichier 'data.json' introuvable dans le Bundle !")
            return
        }
        
        do {
            // 2. Lire les données brutes
            let data = try Data(contentsOf: url)
            
            // 3. Décoder le JSON
            let decoded = try JSONDecoder().decode(JSONWrapper.self, from: data)
            
            // 4. Convertir en objets App (Mapping)
            
            // A. ITEMS
            self.items = decoded.items.map { item in
                ProductionItem(name: item.name, category: item.category, sinkValue: 0)
            }
            
            // B. BUILDINGS
            self.buildings = decoded.buildings.map { b in
                Building(
                    name: b.name,
                    powerConsumption: b.powerConsumption,
                    buildCost: b.buildCost
                )
            }
            
            // C. RECIPES (Le plus important : Lier la recette à la machine)
            self.recipes = decoded.recipes.compactMap { r in
                // On cherche l'objet Building correspondant au nom (ex: "Smelter")
                guard let machineObj = self.buildings.first(where: { $0.name == r.machineName }) else {
                    print("⚠️ Machine introuvable pour la recette : \(r.name) (Machine: \(r.machineName))")
                    return nil
                }
                
                return Recipe(
                    name: r.name,
                    machine: machineObj,
                    ingredients: r.ingredients,
                    products: r.products,
                    isAlternate: r.isAlternate
                )
            }
            
            print("✅ SUCCÈS : Base de données chargée via JSON.")
            print("   - \(items.count) Items")
            print("   - \(buildings.count) Machines")
            print("   - \(recipes.count) Recettes")
            
        } catch {
            print("❌ ERREUR DE DÉCODAGE JSON : \(error)")
        }
    }
    
    // Helper pour trouver les recettes d'un item
    func getRecipes(producing itemName: String) -> [Recipe] {
        return recipes.filter { $0.products.keys.contains(itemName) }
    }
}
