import SwiftUI

struct HubDashboardView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @State private var showingCreateAlert = false
    @State private var newFactoryName = ""
    @State private var animateStats = false
    
    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // HEADER GLOBAL
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(Localization.translate("FICSIT FACTORY OS"))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.ficsitOrange)
                                    .tracking(2)
                                
                                Text(Localization.translate("GLOBAL COMMAND"))
                                    .font(.system(.title, design: .monospaced))
                                    .fontWeight(.heavy)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "globe.europe.africa.fill")
                                .font(.largeTitle)
                                .foregroundColor(.ficsitGray)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // --- GLOBAL STATS ---
                        VStack(spacing: 15) {
                            
                            // TOTAL FACTORIES
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(Localization.translate("ACTIVE FACTORIES"))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.ficsitGray)
                                    
                                    Text("\(viewModel.worldService.world.factories.count)")
                                        .font(.system(size: 40, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.ficsitGray.opacity(0.5))
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .clipShape(FicsitCardShape(cornerSize: 15))
                            .overlay(FicsitCardShape(cornerSize: 15).stroke(Color.ficsitGray.opacity(0.5), lineWidth: 1))
                        }
                        .padding(.horizontal)

                        // --- FACTORY LIST ---
                        VStack(alignment: .leading) {
                            FicsitHeader(title: Localization.translate("Production Sites"), icon: "list.bullet.rectangle.portrait")
                            
                            ForEach(viewModel.worldService.world.factories) { factory in
                                FactoryListCard(factory: factory, isActive: factory.id == viewModel.currentProjectId)
                                    .onTapGesture {
                                        viewModel.loadFactory(factory)
                                        HapticManager.shared.click()
                                    }
                            }

                            // CREATE NEW BUTTON
                            Button(action: {
                                newFactoryName = ""
                                showingCreateAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text(Localization.translate("Establish New Site"))
                                }
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(.ficsitOrange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.ficsitDark.opacity(0.5))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ficsitOrange, style: StrokeStyle(lineWidth: 1, dash: [5])))
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        animateStats = true
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(Localization.translate("New Factory"), isPresented: $showingCreateAlert) {
                TextField(Localization.translate("Name"), text: $newFactoryName)
                Button(Localization.translate("Cancel"), role: .cancel) { }
                Button(Localization.translate("Create")) {
                    viewModel.createNewFactory()
                    // Rename immediat
                    viewModel.currentProjectName = newFactoryName.isEmpty ? "New Factory" : newFactoryName
                    viewModel.saveCurrentFactory() // Force save pour update le nom
                }
            } message: {
                Text(Localization.translate("Enter designation for the new production site."))
            }
        }
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
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(isActive ? .ficsitOrange : .white)

                    if isActive {
                        Text(Localization.translate("ONLINE"))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
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
