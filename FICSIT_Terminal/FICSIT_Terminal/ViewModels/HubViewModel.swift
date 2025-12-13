import Foundation
import Combine
import SwiftUI

enum HubViewState {
    case idle
    case content
    case empty
    case error(String)
}

protocol FactorySelectionDelegate: AnyObject {
    func didSelectFactory(_ factory: Factory)
}

@MainActor
class HubViewModel: ObservableObject {

    // Dependencies
    private let worldService: WorldService
    weak var delegate: FactorySelectionDelegate?

    // State
    @Published var state: HubViewState = .idle
    @Published var factories: [Factory] = []
    @Published var globalFactoryCount: Int = 0
    @Published var showingCreateAlert = false
    @Published var newFactoryName = ""

    private var cancellables = Set<AnyCancellable>()

    init(worldService: WorldService) {
        self.worldService = worldService
        setupBindings()
    }

    private func setupBindings() {
        worldService.worldPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] world in
                guard let self = self else { return }
                self.factories = world.factories.sorted(by: { $0.date > $1.date })
                self.globalFactoryCount = world.factories.count
                self.updateState()
            }
            .store(in: &cancellables)
    }

    private func updateState() {
        if factories.isEmpty {
            state = .empty
        } else {
            state = .content
        }
    }

    // MARK: - Actions

    func createNewFactory() {
        let name = newFactoryName.isEmpty ? "New Factory" : newFactoryName
        var newFactory = Factory.empty()
        newFactory.name = name
        newFactory.date = Date()

        worldService.addFactory(newFactory)
        selectFactory(newFactory)

        // Reset input
        newFactoryName = ""
        showingCreateAlert = false
    }

    func selectFactory(_ factory: Factory) {
        delegate?.didSelectFactory(factory)
    }

    func deleteFactory(_ factory: Factory) {
        worldService.deleteFactory(factory)
    }
}
