import SwiftUI

struct HubDashboardView: View {
    @StateObject var viewModel: HubViewModel
    @ObservedObject var calculatorViewModel: CalculatorViewModel // For selection state sync (legacy/delegate)

    @State private var animateStats = false
    
    init(viewModel: HubViewModel = HubViewModel(), calculatorViewModel: CalculatorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.calculatorViewModel = calculatorViewModel
    }

    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                if !viewModel.currentFactoryId.isEmpty && viewModel.factories.contains(where: { $0.id.uuidString == viewModel.currentFactoryId }) {
                    // SHOW FACTORY DASHBOARD
                    FactoryDashboardView(viewModel: calculatorViewModel) {
                        viewModel.clearSelection()
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    // SHOW HUB LIST
                    ScrollView {
                        VStack(spacing: 25) {

                            // HEADER GLOBAL
                            headerView

                            // --- GLOBAL STATS ---
                            globalStatsView

                            // --- FACTORY LIST ---
                            factoryListView

                            Spacer()
                        }
                    }
                    .transition(.move(edge: .leading))
                }
            }
            .onAppear {
                // Sync Delegate
                viewModel.delegate = calculatorViewModel

                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animateStats = true
                }
            }
            .navigationBarHidden(true)
            .alert(Localization.translate("New Factory"), isPresented: $viewModel.showingCreateAlert) {
                TextField(Localization.translate("Name"), text: $viewModel.newFactoryName)
                Button(Localization.translate("Cancel"), role: .cancel) { }
                Button(Localization.translate("Create")) {
                    viewModel.createNewFactory()
                }
            } message: {
                Text(Localization.translate("Enter designation for the new production site."))
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(Localization.translate("FICSIT FACTORY OS"))
                    .font(.caption) // .monospaced is handled by DesignSystem if applicable or we add it
                    .fontDesign(.monospaced)
                    .foregroundColor(.ficsitOrange)
                    .tracking(2)
                    .accessibilityLabel("System Name")

                Text(Localization.translate("GLOBAL COMMAND"))
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .fontDesign(.monospaced)
                    .foregroundColor(.white)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Image(systemName: "globe.europe.africa.fill")
                .font(.largeTitle)
                .foregroundColor(.ficsitGray)
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private var globalStatsView: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text(Localization.translate("ACTIVE FACTORIES"))
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.ficsitGray)

                    Text("\(viewModel.globalFactoryCount)")
                        .font(.system(size: 40, weight: .black, design: .monospaced)) // Using system(size:) for specific impact but checking if it scales...
                        .minimumScaleFactor(0.5) // Allow scaling down
                        .foregroundColor(.white)
                        .accessibilityLabel("\(viewModel.globalFactoryCount) active factories")
                }
                Spacer()
                Image(systemName: "building.2.fill")
                    .font(.largeTitle)
                    .foregroundColor(.ficsitGray.opacity(0.5))
            }
            .padding()
            .ficsitCard(borderColor: .ficsitGray.opacity(0.5))
        }
        .padding(.horizontal)
    }

    private var factoryListView: some View {
        VStack(alignment: .leading) {
            FicsitHeader(title: Localization.translate("Production Sites"), icon: "list.bullet.rectangle.portrait")

            if case .empty = viewModel.state {
                Text(Localization.translate("No active factories. Initialize new site."))
                    .font(.body)
                    .fontDesign(.monospaced)
                    .foregroundColor(.ficsitGray)
                    .padding()
            } else {
                ForEach(viewModel.factories) { factory in
                    FactoryListCard(factory: factory, isActive: factory.id == calculatorViewModel.currentProjectId)
                        .onTapGesture {
                            viewModel.selectFactory(factory)
                            HapticManager.shared.click()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Factory \(factory.name), \(factory.goals.count) goals")
                        .accessibilityHint("Double tap to activate")
                }
            }

            // CREATE NEW BUTTON
            Button(action: {
                viewModel.newFactoryName = ""
                viewModel.showingCreateAlert = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(Localization.translate("Establish New Site"))
                }
                .font(.headline)
                .fontDesign(.monospaced)
                .foregroundColor(.ficsitOrange)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.ficsitDark.opacity(0.5))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ficsitOrange, style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
            .accessibilityLabel("Create new factory")
        }
        .padding(.horizontal)
    }
}

// Subview for Factory Card
struct FactoryListCard: View {
    let factory: Factory
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(factory.name)
                        .font(.headline)
                        .fontDesign(.monospaced)
                        .fontWeight(.bold)
                        .foregroundColor(isActive ? .ficsitOrange : .white)
                        .lineLimit(1)

                    if isActive {
                        Text(Localization.translate("ONLINE"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                Text("\(factory.goals.count) Goals • \(factory.inputs.count) Inputs")
                    .font(.caption)
                    .foregroundColor(.ficsitGray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(isActive ? .ficsitOrange : .ficsitGray)
        }
        .padding()
        .background(isActive ? Color.ficsitOrange.opacity(0.1) : Color.black.opacity(0.3))
        .clipShape(FicsitCardShape(cornerSize: 10))
        .overlay(FicsitCardShape(cornerSize: 10).stroke(isActive ? Color.ficsitOrange : Color.white.opacity(0.1), lineWidth: 1))
    }
}
