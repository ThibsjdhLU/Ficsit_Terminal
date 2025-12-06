import SwiftUI
import Combine

class CalculatorViewModel: ObservableObject {
    @Published var currentProjectName: String = "Untitled Factory"
    @Published var currentProjectId: UUID = UUID()
    @Published var userInputs: [ResourceInput] = []
    @Published var selectedBeltLevel: BeltLevel = .mk3
    @Published var goals: [ProductionGoal] = []
    @Published var activeRecipes: [String: [Recipe]] = [:]
    
    // RESULTATS
    @Published var maxBundlesPossible: Double = 0 // Gardé pour compatibilité affichage goals
    @Published var consolidatedPlan: [ConsolidatedStep] = []
    @Published var totalPower: Double = 0
    @Published var shoppingList: [ShoppingItem] = []
    
    // NOUVEAU : Resultat SINK
    @Published var sinkResult: SinkResult?
    
    // POWER
    @Published var selectedFuel: PowerFuel = .coal
    @Published var fuelInputAmount: String = "240"
    @Published var powerResult: PowerResult?
    
    private let engine = ProductionEngine()
    private let db = FICSITDatabase.shared
    private let projectService = ProjectService.shared
    private let validator = InputValidator(db: FICSITDatabase.shared)
    
    // NOUVEAU : États pour calcul asynchrone et erreurs
    @Published var isCalculating: Bool = false
    @Published var calculationProgress: Double = 0.0
    @Published var calculationStatus: String = ""
    @Published var lastError: ProductionError?
    private var calculationTask: Task<Void, Never>?
    
    // ... (Fonctions Add/Remove/Update Inputs/Goals/Recipes restent identiques) ...
    // Je ne les remets pas pour raccourcir, copie-les depuis ta version précédente
    func addInput(resource: String, purity: NodePurity, miner: MinerLevel) { userInputs.append(ResourceInput(resourceName: resource, purity: purity, miner: miner)) }
    func updateInput(input: ResourceInput) { if let index = userInputs.firstIndex(where: { $0.id == input.id }) { userInputs[index] = input } }
    func removeInput(at offsets: IndexSet) { userInputs.remove(atOffsets: offsets) }
    func addGoal(item: ProductionItem, ratio: Double) { goals.append(ProductionGoal(item: item, ratio: ratio)) }
    func updateGoal(goal: ProductionGoal) { if let index = goals.firstIndex(where: { $0.id == goal.id }) { goals[index] = goal; maximizeProduction() } }
    func removeGoal(at offsets: IndexSet) { goals.remove(atOffsets: offsets) }
    func toggleRecipe(for item: String, recipe: Recipe) {
        var currentList = activeRecipes[item] ?? []
        if let index = currentList.firstIndex(where: { $0.id == recipe.id }) {
            currentList.remove(at: index)
        } else {
            currentList.append(recipe)
        }
        activeRecipes[item] = currentList
        // Invalider le cache quand les recettes changent
        engine.invalidateCache()
        maximizeProduction()
    }
    func isRecipeActive(item: String, recipe: Recipe) -> Bool { let list = activeRecipes[item] ?? []; if list.isEmpty { return !recipe.isAlternate }; return list.contains(where: { $0.id == recipe.id }) }
    func saveCurrentProject(name: String) { self.currentProjectName = name; let project = ProjectData(id: currentProjectId, name: name, date: Date(), inputs: userInputs, goals: goals, activeRecipes: activeRecipes, beltLevel: selectedBeltLevel, fuelType: selectedFuel, fuelAmount: fuelInputAmount); projectService.saveProject(project) }
    func loadProject(_ project: ProjectData) { self.currentProjectId = project.id; self.currentProjectName = project.name; self.userInputs = project.inputs; self.goals = project.goals; self.activeRecipes = project.activeRecipes; self.selectedBeltLevel = project.beltLevel; self.selectedFuel = project.fuelType; self.fuelInputAmount = project.fuelAmount; maximizeProduction(); calculatePower() }
    func createNewProject() { self.currentProjectId = UUID(); self.currentProjectName = "New Factory"; self.userInputs = []; self.goals = []; self.activeRecipes = [:]; self.consolidatedPlan = []; self.shoppingList = []; self.powerResult = nil; self.fuelInputAmount = ""; self.sinkResult = nil }
    
    // --- COEUR DE L'APPEL ---
    func maximizeProduction() {
        // Annuler le calcul précédent s'il existe
        calculationTask?.cancel()
        
        guard !goals.isEmpty else {
            consolidatedPlan = []
            sinkResult = nil
            lastError = nil
            return
        }
        
        // Réinitialiser les états
        isCalculating = true
        calculationProgress = 0.0
        calculationStatus = "Validation..."
        lastError = nil
        
        // Lancer le calcul en arrière-plan
        calculationTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Validation
                await MainActor.run {
                    self.calculationProgress = 0.1
                    self.calculationStatus = "Validation des données..."
                }
                
                try self.validator.validateAll(
                    inputs: self.userInputs,
                    goals: self.goals,
                    activeRecipes: self.activeRecipes
                )
                
                // Calcul des coûts
                await MainActor.run {
                    self.calculationProgress = 0.2
                    self.calculationStatus = "Calcul des coûts..."
                }
                
                // Simulation de production
                await MainActor.run {
                    self.calculationProgress = 0.5
                    self.calculationStatus = "Optimisation de la production..."
                }
                
                // Appel au moteur (peut throw)
                let result = try self.engine.calculateAbsoluteAllocation(
                    goals: self.goals,
                    availableInputs: self.userInputs,
                    beltLimit: self.selectedBeltLevel.speed,
                    activeRecipes: self.activeRecipes
                )
                
                // Génération des étapes
                await MainActor.run {
                    self.calculationProgress = 0.8
                    self.calculationStatus = "Génération du plan..."
                }
                
                // Mise à jour des résultats
                await MainActor.run {
                    self.consolidatedPlan = result.steps
                    self.sinkResult = result.sinkReport
                    
                    // On recalcule le "maxBundle" approximatif pour l'affichage des badges goals
                    if let firstGoal = self.goals.first,
                       let step = result.steps.first(where: { $0.item.name == firstGoal.item.name }),
                       firstGoal.ratio > 0 {
                        self.maxBundlesPossible = step.totalRate / firstGoal.ratio
                    } else {
                        self.maxBundlesPossible = 0
                    }
                    
                    self.totalPower = result.steps.reduce(0) { $0 + $1.powerUsage }
                    self.calculateShoppingList()
                    
                    // Finalisation
                    self.calculationProgress = 1.0
                    self.calculationStatus = "Terminé"
                    self.isCalculating = false
                }
                
            } catch let error as ProductionError {
                await MainActor.run {
                    self.lastError = error
                    self.isCalculating = false
                    self.calculationStatus = "Erreur"
                    // Garder les résultats précédents en cas d'erreur
                }
            } catch {
                await MainActor.run {
                    self.lastError = ProductionError.invalidInput(message: error.localizedDescription)
                    self.isCalculating = false
                    self.calculationStatus = "Erreur"
                }
            }
        }
    }
    
    func cancelCalculation() {
        calculationTask?.cancel()
        isCalculating = false
        calculationStatus = "Annulé"
    }
    
    private func calculateShoppingList() {
        var totals: [String: Int] = [:]
        for step in consolidatedPlan {
            let machinesToBuild = Int(ceil(step.machineCount))
            guard let recipe = step.recipe else { continue }
            let building = recipe.machine
            for (matName, matQty) in building.buildCost {
                let totalMat = matQty * machinesToBuild
                totals[matName] = (totals[matName] ?? 0) + totalMat
            }
        }
        self.shoppingList = totals.map { (name, count) in
            // Utiliser la version optimisée
            let itemObj = db.getItemOptimized(named: name) ?? ProductionItem(name: name, category: "Part")
            return ShoppingItem(item: itemObj, count: count)
        }.sorted { $0.item.name < $1.item.name }
    }
    
    func calculatePower() {
        guard let amount = Double(fuelInputAmount) else { return }
        self.powerResult = engine.calculatePowerScenario(fuel: selectedFuel, amountAvailable: amount)
    }
}
