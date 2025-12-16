import Foundation
import Combine
import SwiftUI

@MainActor
class ExtractionViewModel: ObservableObject {
    // Inputs
    @Published var selectedResource: ProductionItem?
    @Published var selectedPurity: NodePurity = .normal
    @Published var selectedMiner: MinerLevel = .mk1
    @Published var clockSpeed: Double = 1.0 // 100%

    // Outputs
    @Published var extractionRate: Double = 0.0
    @Published var powerConsumption: Double = 0.0
    @Published var mapStats: MapResourceNodeCount?

    // Search
    @Published var searchText: String = ""
    @Published var filteredItems: [ProductionItem] = []

    private let database = FICSITDatabase.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Filter only raw resources
        self.filteredItems = database.items.filter { database.rawResources.contains($0.name) }

        // Setup listeners
        setupBindings()
    }

    private func setupBindings() {
        // Recalculate when inputs change
        Publishers.CombineLatest4($selectedResource, $selectedPurity, $selectedMiner, $clockSpeed)
            .sink { [weak self] _ in self?.calculate() }
            .store(in: &cancellables)

        // Search
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                let allRaw = self.database.items.filter { self.database.rawResources.contains($0.name) }
                if text.isEmpty {
                    self.filteredItems = allRaw
                } else {
                    self.filteredItems = allRaw.filter { $0.name.localizedCaseInsensitiveContains(text) }
                }
            }
            .store(in: &cancellables)
    }

    func select(_ item: ProductionItem) {
        self.selectedResource = item
        self.mapStats = WorldResourceDatabase.get(resource: item.name)
    }

    private func calculate() {
        guard let _ = selectedResource else {
            extractionRate = 0
            powerConsumption = 0
            return
        }

        // Rate Calculation
        // Formula: Base * PurityMultiplier * ClockSpeed
        let base = selectedMiner.baseExtractionRate
        let purity = selectedPurity.multiplier

        self.extractionRate = base * purity * clockSpeed

        // Power Calculation (Simplified)
        // Formula: BasePower * (ClockSpeed/100)^1.6
        // Miner Mk1: 5MW, Mk2: 12MW, Mk3: 30MW
        let basePower: Double
        switch selectedMiner {
        case .mk1: basePower = 5
        case .mk2: basePower = 12
        case .mk3: basePower = 30
        }

        self.powerConsumption = basePower * pow(clockSpeed, 1.6)
    }
}
