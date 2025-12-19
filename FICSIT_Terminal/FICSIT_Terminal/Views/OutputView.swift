import SwiftUI

struct OutputView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @State private var selectedItem: ProductionItem?
    @State private var ratioStr: String = "1"
    @State private var showShoppingList = false
    @State private var showSearchSheet = false
    @State private var showProductionInputSheet = false // New
    @State private var editingGoal: ProductionGoal?
    
    var body: some View {
        ZStack {
            FicsitBackground()

            VStack(spacing: 0) {
                // 1. ZONE FIXE
                VStack(spacing: 15) {
                    headerView
                    inputSection
                    goalsList
                    actionButtons
                }
                .padding()
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.1)), alignment: .bottom)
                
                // 2. ZONE SCROLLABLE
                ScrollView {
                    resultsSection.padding(.vertical)
                }
            }
        }
        .sheet(item: $editingGoal) { goal in EditGoalSheet(goal: goal, viewModel: viewModel) }
        .sheet(isPresented: $showShoppingList) { ShoppingListView(viewModel: viewModel) }
        .sheet(isPresented: $showProductionInputSheet) {
            ProductionInputView(viewModel: viewModel, db: db) // The new "Production Input Screen"
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.foregroundColor(.ficsitOrange)
            }
        }
    }
    
    // --- SOUS-VUES ---
    
    private var headerView: some View {
        Text(Localization.translate("PRODUCTION MANAGEMENT")).font(.system(.headline, design: .monospaced)).foregroundColor(.ficsitOrange)
    }
    
    private var inputSection: some View {
        HStack {
            // Simplified "Add Goal" button that opens the detailed Production Input View
            Button(action: { showProductionInputSheet = true }) {
                HStack {
                    Image(systemName: "plus.square.fill")
                    Text(Localization.translate("Add Product Goal"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.ficsitOrange.opacity(0.2))
                .foregroundColor(.ficsitOrange)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ficsitOrange, style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
        }
    }
    
    private var goalsList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(viewModel.goals) { goal in
                    Button(action: { editingGoal = goal }) {
                        HStack {
                            Text(goal.item.localizedName).font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                            Text("x\(String(format: "%.1f", goal.ratio))").font(.system(.caption, design: .monospaced)).fontWeight(.bold).foregroundColor(.ficsitOrange)
                        }.padding(8).background(Color.ficsitGray.opacity(0.3)).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
            }.padding(.horizontal, 4)
        }.frame(height: 40)
    }
    
    private var actionButtons: some View {
        HStack {
            Button(action: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                viewModel.maximizeProduction()
                HapticManager.shared.thud()
            }) {
                Text(Localization.translate("CALCULATE"))
            }
            .buttonStyle(FicsitButtonStyle())
            .disabled(viewModel.isCalculating)
            
            if viewModel.isCalculating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .ficsitOrange))
                    .frame(width: 60)
            } else {
                Button(action: { showShoppingList = true }) {
                    Image(systemName: "cart.fill")
                }
                .buttonStyle(FicsitButtonStyle(primary: false, color: .white))
                .frame(width: 60)
            }
        }
    }
    
    private var resultsSection: some View {
        VStack(spacing: 20) {
            // Affichage de la progression
            if viewModel.isCalculating {
                VStack(spacing: 10) {
                    ProgressView(value: viewModel.calculationProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .ficsitOrange))
                    Text(viewModel.calculationStatus)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.ficsitGray)
                }
                .padding()
            }
            
            // Affichage des erreurs
            if let error = viewModel.lastError {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3))
                        Text(Localization.translate("ERROR"))
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3))
                    }
                    Text(error.localizedDescription)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.ficsitOrange)
                            .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color(red: 0.8, green: 0.3, blue: 0.3).opacity(0.2))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.8, green: 0.3, blue: 0.3), lineWidth: 1))
            }
            
            if !viewModel.consolidatedPlan.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack { Text(Localization.translate("POWER USAGE")); Spacer(); Text("\(Int(viewModel.totalPower)) MW").foregroundColor(.yellow) }
                        .font(.system(.caption, design: .monospaced)).padding().background(Color.black.opacity(0.3))
                    Divider().background(Color.ficsitGray)
                    
                    // NOUVEAU : AFFICHER LES VRAIS TAUX DE PRODUCTION
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Localization.translate("REAL OUTPUTS")).font(.system(.caption2, design: .monospaced)).fontWeight(.black).foregroundColor(.ficsitGray).padding(.top, 5)
                        ForEach(viewModel.goals) { goal in
                            HStack {
                                Text(goal.item.localizedName).font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                                Spacer()
                                let realRate = getRealRate(for: goal)
                                Text(verbatim: "\(String(format: "%.1f", realRate))/m").foregroundColor(.ficsitOrange).font(.system(.body, design: .monospaced)).fontWeight(.bold)
                            }
                        }
                    }.padding()
                    Divider().background(Color.ficsitGray)
                    
                    let grouped = Dictionary(grouping: viewModel.consolidatedPlan, by: { $0.buildingName })
                    ForEach(grouped.keys.sorted(), id: \.self) { buildingName in
                        VStack(alignment: .leading) {
                            Text(Localization.translate(buildingName).uppercased()).font(.system(.caption2, design: .monospaced)).fontWeight(.black).foregroundColor(.ficsitGray).padding(.horizontal).padding(.top, 10)
                            if let steps = grouped[buildingName] {
                                ForEach(steps) { step in MachineRow(step: step).padding(.horizontal) }
                            }
                        }
                    }.padding(.bottom)
                }.background(Color.white.opacity(0.02)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal)
            } else if !viewModel.goals.isEmpty {
                Text(Localization.translate("Insufficient resources or bottleneck detected.")).font(.system(.caption, design: .monospaced)).foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3)).padding()
            }
        }
    }
    
    func getRealRate(for goal: ProductionGoal) -> Double {
        if let step = viewModel.consolidatedPlan.first(where: { $0.item.name == goal.item.name }) { return step.totalRate }
        return 0.0
    }
}

struct EditGoalSheet: View {
    @State var goal: ProductionGoal
    @ObservedObject var viewModel: CalculatorViewModel
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                Form {
                    Section(header: Text(Localization.translate("Target Ratio"))) {
                        Text(goal.item.localizedName).foregroundColor(.ficsitGray)
                        TextField("Ratio", value: $goal.ratio, format: .number).keyboardType(.decimalPad)
                    }
                    Section {
                        Button(Localization.translate("Delete Goal")) { if let index = viewModel.goals.firstIndex(where: {$0.id == goal.id}) { viewModel.removeGoal(at: IndexSet(integer: index)) }; presentationMode.wrappedValue.dismiss() }.foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3))
                    }
                }.scrollContentBackground(.hidden).background(Color.ficsitDark)
            }.navigationTitle(Localization.translate("Edit Goal")).navigationBarItems(trailing: Button(Localization.translate("Save")) { viewModel.updateGoal(goal: goal); presentationMode.wrappedValue.dismiss() })
        }
    }
}
