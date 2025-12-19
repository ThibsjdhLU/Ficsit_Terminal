import SwiftUI

struct ProductionPlannerView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase

    // Internal Tab State
    enum PlannerTab: Int, CaseIterable, Identifiable {
        case inputs, production, graph, power

        var id: Int { self.rawValue }

        var title: String {
            switch self {
            case .inputs: return Localization.translate("Inputs")
            case .production: return Localization.translate("Production")
            case .graph: return Localization.translate("Graph")
            case .power: return Localization.translate("Power")
            }
        }

        var icon: String {
            switch self {
            case .inputs: return "cube.box.fill"
            case .production: return "gearshape.2.fill"
            case .graph: return "arrow.triangle.branch"
            case .power: return "bolt.fill"
            }
        }
    }

    @State private var currentTab: PlannerTab = .inputs

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Segmented Control (Sub-Navigation)
                Picker("", selection: $currentTab) {
                    ForEach(PlannerTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color.ficsitDark)

                // Content
                ZStack {
                    switch currentTab {
                    case .inputs:
                        InputView(viewModel: viewModel, db: db)
                    case .production:
                        OutputView(viewModel: viewModel, db: db)
                    case .graph:
                        FactoryFlowGraphView(viewModel: viewModel, db: db)
                    case .power:
                        PowerPlannerView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
            .background(Color.ficsitDark.ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
