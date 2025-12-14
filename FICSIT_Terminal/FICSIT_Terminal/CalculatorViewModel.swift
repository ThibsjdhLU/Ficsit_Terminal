import SwiftUI
import Combine

class CalculatorViewModel: ObservableObject, FactorySelectionDelegate {
    // MARK: - WORLD STATE
    let worldService: WorldService

    // MARK: - ACTIVE FACTORY STATE
    @Published var currentProjectName: String = ""
    @Published var currentProjectId: UUID = UUID()
    @Published var userInputs: [ResourceInput] = []
    @Published var selectedBeltLevel: BeltLevel = .mk3
    @Published var goals: [ProductionGoal] = []
    @Published var activeRecipes: [String: [Recipe]] = [:]
    
    // Power Config (Factory Specific)
    @Published var selectedFuel: PowerFuel = .coal
    @Published var fuelInputAmount: String = "240"

    // MARK: - RESULTS
    @Published var maxBundlesPossible: Double = 0
    @Published var consolidatedPlan: [ConsolidatedStep] = []
    @Published var totalPower: Double = 0
    @Published var shoppingList: [ShoppingItem] = []
    @Published var powerResult: PowerResult?
    @Published var sinkResult: SinkResult?
    
    // MARK: - CALCULATION STATE
    @Published var isCalculating: Bool = false
    @Published var calculationProgress: Double = 0.0
    @Published var calculationStatus: String = ""
    @Published var lastError: ProductionError?

    private var calculationTask: Task<Void, Never>?
    private var autoSaveCancellable: AnyCancellable?

    // Dependencies
    private let engine = ProductionEngine()
    private let db = FICSITDatabase.shared
    private let validator = InputValidator(db: FICSITDatabase.shared)

    init(worldService: WorldService) {
        self.worldService = worldService

        // Wait for world to load if needed (this is tricky in init, ideally handled by a loading state)
        // For now, we assume WorldService might be async loading.

        setupAutoSave()

        // Initial load check
        if let lastID = worldService.getLastActiveFactoryID(),
           let factory = worldService.getFactory(id: lastID) {
            loadFactoryInternal(factory)
        } else {
            // Check if world is loaded?
            // If world is empty, we might need to wait or create new.
            // Since WorldService.loadWorld() is async now, this synchronous init might miss the data.
            // We should listen to world updates.
            setupWorldObservation()
        }
    }

    private func setupWorldObservation() {
        worldService.worldPublisher
            .first() // Just get the initial load or first update
            .receive(on: RunLoop.main)
            .sink { [weak self] world in
                guard let self = self else { return }
                if self.currentProjectName.isEmpty { // Only if not already loaded
                    if let lastID = self.worldService.getLastActiveFactoryID(),
                       let factory = self.worldService.getFactory(id: lastID) {
                        self.loadFactoryInternal(factory)
                    } else if let first = world.factories.first {
                        self.loadFactoryInternal(first)
                    } else {
                        self.createNewFactory()
                    }
                }
            }
            .store(in: &autoSaveCancellableSet) // Need a set for this
    }

    private var autoSaveCancellableSet = Set<AnyCancellable>()

    // MARK: - AUTO SAVE & SYNC
    private func setupAutoSave() {
        // On observe les changements des propriétés clés pour déclencher la sauvegarde
        Publishers.MergeMany(
            $currentProjectName.map { _ in () }.eraseToAnyPublisher(),
            $userInputs.map { _ in () }.eraseToAnyPublisher(),
            $goals.map { _ in () }.eraseToAnyPublisher(),
            $activeRecipes.map { _ in () }.eraseToAnyPublisher(),
            $selectedBeltLevel.map { _ in () }.eraseToAnyPublisher(),
            $selectedFuel.map { _ in () }.eraseToAnyPublisher(),
            $fuelInputAmount.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.saveCurrentFactory()
        }
        .store(in: &autoSaveCancellableSet)
    }

    func saveCurrentFactory() {
        let factory = Factory(
            id: currentProjectId,
            name: currentProjectName,
            date: Date(),
            inputs: userInputs,
            goals: goals,
            activeRecipes: activeRecipes,
            beltLevel: selectedBeltLevel,
            fuelType: selectedFuel,
            fuelAmount: fuelInputAmount
        )
        worldService.updateFactory(factory)
        // print("Auto-saved factory: \(currentProjectName)")
    }

    // MARK: - FACTORY MANAGEMENT

    // FactorySelectionDelegate implementation
    func didSelectFactory(_ factory: Factory) {
        loadFactory(factory)
    }

    func createNewFactory() {
        let newFactory = Factory.empty()
        worldService.addFactory(newFactory)
        loadFactoryInternal(newFactory)
    }

    func loadFactory(_ factory: Factory) {
        // Sauvegarder l'état actuel avant de changer (au cas où le debounce n'est pas passé)
        saveCurrentFactory()
        loadFactoryInternal(factory)
    }

    private func loadFactoryInternal(_ factory: Factory) {
        self.currentProjectId = factory.id
        self.currentProjectName = factory.name
        self.userInputs = factory.inputs
        self.goals = factory.goals
        self.activeRecipes = factory.activeRecipes
        self.selectedBeltLevel = factory.beltLevel
        self.selectedFuel = factory.fuelType
        self.fuelInputAmount = factory.fuelAmount

        worldService.setLastActiveFactoryID(factory.id)

        // Relancer les calculs
        maximizeProduction()
        calculatePower()
    }

    func deleteFactory(_ factory: Factory) {
        worldService.deleteFactory(factory)
        if currentProjectId == factory.id {
            // Si on supprime l'usine courante, charger une autre ou créer une nouvelle
            if let other = worldService.world.factories.first {
                loadFactoryInternal(other)
            } else {
                createNewFactory()
            }
        }
    }

    // MARK: - INPUTS & GOALS ACTIONS

    func addInput(resource: String, purity: NodePurity, miner: MinerLevel) {
        userInputs.append(ResourceInput(resourceName: resource, sourceType: .node(purity: purity, miner: miner)))
    }

    // Nouveau : Import depuis usine
    func addImportInput(resource: String, fromFactoryID: UUID) {
        userInputs.append(ResourceInput(resourceName: resource, sourceType: .factory(id: fromFactoryID)))
    }

    func updateInput(input: ResourceInput) {
        if let index = userInputs.firstIndex(where: { $0.id == input.id }) {
            userInputs[index] = input
        }
    }

    func removeInput(at offsets: IndexSet) {
        userInputs.remove(atOffsets: offsets)
    }

    func addGoal(item: ProductionItem, ratio: Double) {
        goals.append(ProductionGoal(item: item, ratio: ratio))
    }

    func updateGoal(goal: ProductionGoal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            maximizeProduction()
        }
    }

    func removeGoal(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
    }
    
    func toggleRecipe(for item: String, recipe: Recipe) {
        var currentList = activeRecipes[item] ?? []
        if let index = currentList.firstIndex(where: { $0.id == recipe.id }) {
            currentList.remove(at: index)
        } else {
            currentList.append(recipe)
        }
        activeRecipes[item] = currentList
        engine.invalidateCache()
        maximizeProduction()
    }
    
    func isRecipeActive(item: String, recipe: Recipe) -> Bool {
        let list = activeRecipes[item] ?? []
        if list.isEmpty { return !recipe.isAlternate }
        return list.contains(where: { $0.id == recipe.id })
    }

    // MARK: - PRODUCTION CALCULATION

    func maximizeProduction() {
        calculationTask?.cancel()
        
        guard !goals.isEmpty else {
            consolidatedPlan = []
            sinkResult = nil
            lastError = nil
            return
        }
        
        isCalculating = true
        calculationProgress = 0.0
        calculationStatus = "Validation..."
        lastError = nil
        
        // Copie locale pour la closure
        let currentInputs = self.userInputs
        let currentGoals = self.goals
        let currentRecipes = self.activeRecipes
        let currentBeltSpeed = self.selectedBeltLevel.speed

        calculationTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // 1. Résoudre les Inputs dynamiques (Imports)
                var resolvedInputs: [ResourceInput] = []
                
                await MainActor.run {
                    self.calculationStatus = "Résolution des imports..."
                }
                
                // Pré-traitement des inputs
                for input in currentInputs {
                    switch input.sourceType {
                    case .node:
                        resolvedInputs.append(input)
                    case .factory(let sourceID):
                        // Calcul du montant importé (Logic placeholder)
                        let importedAmount = self.resolveImportAmount(from: sourceID, item: input.resourceName)

                        // FIX LOGISTIQUE : Injecter le montant résolu via customRate
                        var resolvedInput = input
                        resolvedInput.customRate = importedAmount
                        resolvedInputs.append(resolvedInput)
                    }
                }
                
                // 2. Validation
                try self.validator.validateAll(inputs: resolvedInputs, goals: currentGoals, activeRecipes: currentRecipes)

                await MainActor.run { self.calculationProgress = 0.3; self.calculationStatus = "Calcul..." }

                // 3. Calcul Moteur
                let result = try self.engine.calculateAbsoluteAllocation(
                    goals: currentGoals,
                    availableInputs: resolvedInputs,
                    beltLimit: currentBeltSpeed,
                    activeRecipes: currentRecipes
                )
                
                // 4. Update UI
                await MainActor.run {
                    self.consolidatedPlan = result.steps
                    self.sinkResult = result.sinkReport
                    
                    if let firstGoal = currentGoals.first,
                       let step = result.steps.first(where: { $0.item.name == firstGoal.item.name }),
                       firstGoal.ratio > 0 {
                        self.maxBundlesPossible = step.totalRate / firstGoal.ratio
                    } else {
                        self.maxBundlesPossible = 0
                    }
                    
                    self.totalPower = result.steps.reduce(0) { $0 + $1.powerUsage }
                    self.calculateShoppingList()
                    
                    self.calculationProgress = 1.0
                    self.calculationStatus = "Terminé"
                    self.isCalculating = false
                }
                
            } catch let error as ProductionError {
                await MainActor.run { self.lastError = error; self.isCalculating = false; self.calculationStatus = "Erreur" }
            } catch {
                await MainActor.run { self.lastError = ProductionError.invalidInput(message: error.localizedDescription); self.isCalculating = false; self.calculationStatus = "Erreur" }
            }
        }
    }
    
    // Placeholder pour la logique logistique
    private func resolveImportAmount(from factoryID: UUID, item: String) -> Double {
        // TODO: Implémenter la logique réelle de surplus en chargeant l'usine source
        // Pour l'instant, on retourne 600 (Mk5 Belt max-ish) pour permettre la planification
        return 600.0
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
            let itemObj = db.getItemOptimized(named: name) ?? ProductionItem(name: name, category: "Part")
            return ShoppingItem(item: itemObj, count: count)
        }.sorted { $0.item.name < $1.item.name }
    }
    
    func calculatePower() {
        guard let amount = Double(fuelInputAmount) else { return }
        self.powerResult = engine.calculatePowerScenario(fuel: selectedFuel, amountAvailable: amount)
    }
}
