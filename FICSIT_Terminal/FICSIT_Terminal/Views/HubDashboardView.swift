import SwiftUI

struct HubDashboardView: View {
    @ObservedObject var viewModel: HubViewModel
    @ObservedObject var calculatorViewModel: CalculatorViewModel
    @Binding var selectedTab: Int // Binding pour navigation globale
    
    // Search State (Global)
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [ProductionItem] = []

    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // HEADER
                        HStack {
                            VStack(alignment: .leading) {
                                Text(Localization.translate("FICSIT OS"))
                                    .font(.caption).fontDesign(.monospaced)
                                    .foregroundColor(.ficsitOrange)
                                Text(Localization.translate("DASHBOARD"))
                                    .font(.largeTitle).fontWeight(.heavy).fontDesign(.monospaced)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "globe.europe.africa.fill")
                                .font(.largeTitle)
                                .foregroundColor(.ficsitGray)
                        }
                        .padding()

                        // ACTIVE FACTORY CARD
                        if let current = viewModel.factories.first(where: { $0.id == calculatorViewModel.currentProjectId }) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(Localization.translate("CURRENT PROJECT"))
                                        .font(.caption).bold().foregroundColor(.ficsitOrange)
                                    Spacer()
                                    Text(Localization.translate("ONLINE"))
                                        .font(.caption).bold()
                                        .padding(4)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }

                                Text(current.name)
                                    .font(.title).bold().fontDesign(.monospaced)
                                    .foregroundColor(.white)

                                HStack {
                                    Label("\(current.goals.count) Goals", systemImage: "target")
                                    Spacer()
                                    Label("\(current.inputs.count) Inputs", systemImage: "arrow.down.circle")
                                }
                                .font(.subheadline).foregroundColor(.gray)

                                Divider().background(Color.gray)

                                Button(action: {
                                    selectedTab = 2 // Switch to Factory/Output Tab
                                    HapticManager.shared.click()
                                }) {
                                    Text(Localization.translate("Open Calculator"))
                                        .font(.headline).bold()
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(Color.ficsitOrange)
                                        .foregroundColor(.black)
                                        .cornerRadius(4)
                                }
                            }
                            .padding()
                            .ficsitCard(borderColor: .ficsitOrange)
                            .padding(.horizontal)
                        } else {
                            // Empty State if no project is active/exists
                            VStack(spacing: 15) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.ficsitOrange)
                                Text(Localization.translate("Establish New Site"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Button(action: { viewModel.showingCreateAlert = true }) {
                                    Text(Localization.translate("New Project"))
                                        .padding()
                                        .background(Color.ficsitOrange)
                                        .foregroundColor(.black)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .ficsitCard(borderColor: .gray)
                            .padding(.horizontal)
                        }

                        // FACTORY LIST
                        VStack(alignment: .leading) {
                            HStack {
                                Text(Localization.translate("ALL PROJECTS"))
                                    .font(.headline).fontDesign(.monospaced)
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { viewModel.showingCreateAlert = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.ficsitOrange)
                                }
                                .accessibilityLabel(Localization.translate("New Project"))
                            }
                            .padding(.horizontal)

                            ForEach(viewModel.factories) { factory in
                                Button(action: {
                                    viewModel.selectFactory(factory)
                                    HapticManager.shared.click()
                                }) {
                                    FactoryListCard(factory: factory, isActive: factory.id == calculatorViewModel.currentProjectId)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .alert(Localization.translate("New Project"), isPresented: $viewModel.showingCreateAlert) {
                TextField(Localization.translate("Project Name"), text: $viewModel.newFactoryName)
                Button(Localization.translate("Cancel"), role: .cancel) { }
                Button(Localization.translate("Create")) { viewModel.createNewFactory() }
            } message: {
                Text(Localization.translate("Enter a name for your factory."))
            }
            .navigationBarHidden(true)
        }
    }
}

// Subcomponents

struct FactoryListCard: View {
    let factory: Factory
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(factory.name)
                    .font(.headline)
                    .foregroundColor(isActive ? .ficsitOrange : .white)
                Text("\(factory.goals.count) goals")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .ficsitCard(borderColor: isActive ? .ficsitOrange : .gray.opacity(0.5))
    }
}
