import SwiftUI

struct HubDashboardView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @State private var animateStats = false
    
    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // HEADER
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(Localization.translate("WELCOME, PIONEER"))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.ficsitOrange)
                                    .tracking(2)
                                
                                Text(viewModel.currentProjectName.uppercased())
                                    .font(.system(.title, design: .monospaced))
                                    .fontWeight(.heavy)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "person.crop.square.fill")
                                .font(.largeTitle)
                                .foregroundColor(.ficsitGray)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // DASHBOARD CARDS
                        VStack(spacing: 15) {
                            
                            // CARTE 1 : STATUT ÉNERGIE
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(Localization.translate("GRID STATUS"))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.ficsitGray)
                                    
                                    let load: Double = {
                                        if let powerResult = viewModel.powerResult, powerResult.totalMW > 0 {
                                            return viewModel.totalPower / powerResult.totalMW
                                        } else {
                                            return 0
                                        }
                                    }()
                                    
                                    Text("\(Int(load * 100))%")
                                        .font(.system(size: 40, weight: .black, design: .monospaced))
                                        .foregroundColor(load > 1.0 ? Color(red: 0.8, green: 0.3, blue: 0.3) : (load > 0.8 ? .yellow : .green))
                                        .scaleEffect(animateStats ? 1.0 : 0.8)
                                        .opacity(animateStats ? 1.0 : 0.0)
                                    
                                    if viewModel.isCalculating {
                                        HStack {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .ficsitOrange))
                                                .scaleEffect(0.7)
                                            Text(Localization.translate("CALCULATING..."))
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.ficsitOrange)
                                        }
                                        .padding(4)
                                        .background(Color.ficsitOrange.opacity(0.2))
                                        .cornerRadius(4)
                                    } else {
                                        Text(Localization.translate("OPERATIONAL"))
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.green)
                                            .padding(4)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                Spacer()
                                Image(systemName: "bolt.ring.closed")
                                    .font(.system(size: 40))
                                    .foregroundColor(.ficsitOrange.opacity(0.5))
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .clipShape(FicsitCardShape(cornerSize: 15))
                            .overlay(FicsitCardShape(cornerSize: 15).stroke(Color.ficsitOrange, lineWidth: 1))
                            
                            // CARTE 2 : PRODUCTION EN COURS
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(Localization.translate("ACTIVE GOALS"))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.ficsitGray)
                                    
                                    if viewModel.goals.isEmpty {
                                        Text(Localization.translate("IDLE"))
                                            .font(.system(.title2, design: .monospaced))
                                            .foregroundColor(.ficsitGray)
                                            .padding(.top, 5)
                                    } else {
                                        ForEach(viewModel.goals.prefix(3)) { goal in
                                            HStack {
                                                Text("• \(goal.item.localizedName)")
                                                    .foregroundColor(.white)
                                                Spacer()
                                                
                                                // CORRECTION ICI : On va chercher le VRAI taux calculé
                                                let realRate = getRealRate(for: goal)
                                                Text(String(format: "%.1f/m", realRate))
                                                    .foregroundColor(.ficsitOrange)
                                            }
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(.vertical, 2)
                                        }
                                        if viewModel.goals.count > 3 {
                                            Text("+ \(viewModel.goals.count - 3) \(Localization.translate("others..."))")
                                                .font(.caption)
                                                .foregroundColor(.ficsitGray)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .clipShape(FicsitCardShape(cornerSize: 15))
                            .overlay(FicsitCardShape(cornerSize: 15).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            
                            // SINK CARD
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "ticket.fill").foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.8))
                                    Text(Localization.translate("A.W.E.S.O.M.E. SINK")).font(.system(size: 10, design: .monospaced)).foregroundColor(.ficsitGray)
                                }
                                Spacer()
                                if let sink = viewModel.sinkResult {
                                    Text("\(sink.totalPoints)")
                                        .font(.system(size: 24, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text(Localization.translate("POINTS/MIN"))
                                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.ficsitGray)
                                    Text("\(Localization.translate("via")) \(sink.bestItem.localizedName)")
                                        .font(.system(size: 8, design: .monospaced)).foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.8))
                                } else {
                                    Text("0")
                                        .font(.system(size: 30, weight: .black, design: .monospaced))
                                        .foregroundColor(.ficsitGray)
                                    Text(Localization.translate("NO OVERFLOW"))
                                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.ficsitGray)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading) // Alignement gauche forcé
                            .background(Color.black.opacity(0.4))
                            .clipShape(FicsitCardShape(cornerSize: 15))
                            .overlay(FicsitCardShape(cornerSize: 15).stroke(Color(red: 0.6, green: 0.2, blue: 0.8), lineWidth: 1))
                        }
                        .padding(.horizontal)
                        
                        // SHORTCUTS
                        VStack(alignment: .leading) {
                            FicsitHeader(title: Localization.translate("Quick Actions"), icon: "command")
                            
                            HStack {
                                Button(action: {
                                    viewModel.createNewProject()
                                    HapticManager.shared.thud()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.square.dashed")
                                        Text(Localization.translate("New Project"))
                                    }
                                }
                                .buttonStyle(FicsitButtonStyle(primary: false, color: .ficsitGray))
                                
                                Button(action: {
                                    // Placeholder pour future feature Notes
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text(Localization.translate("Notes"))
                                    }
                                }
                                .buttonStyle(FicsitButtonStyle(primary: false, color: .ficsitGray))
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
        }
    }
    
    // Helper pour trouver le taux réel dans le plan calculé
    func getRealRate(for goal: ProductionGoal) -> Double {
        // On cherche l'étape qui produit l'item du goal
        if let step = viewModel.consolidatedPlan.first(where: { $0.item.name == goal.item.name }) {
            return step.totalRate
        }
        return 0.0
    }
}

// Composant Bouton Dashboard (réintégré si manquant)
struct DashboardButton: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
                .padding(.bottom, 5)
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color.black.opacity(0.4))
        .clipShape(FicsitCardShape(cornerSize: 10))
        .overlay(FicsitCardShape(cornerSize: 10).stroke(color.opacity(0.5), lineWidth: 1))
    }
}
