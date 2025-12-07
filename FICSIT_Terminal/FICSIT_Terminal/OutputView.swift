import SwiftUI

struct OutputView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @State private var selectedItem: ProductionItem?
    @State private var ratioStr: String = "1"
    @State private var showShoppingList = false
    @State private var showSearchSheet = false
    @State private var editingGoal: ProductionGoal?
    
    var body: some View {
        NavigationView {
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
            .navigationBarHidden(true)
            .sheet(item: $editingGoal) { goal in EditGoalSheet(goal: goal, viewModel: viewModel) }
            .sheet(isPresented: $showShoppingList) { ShoppingListView(viewModel: viewModel) }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.foregroundColor(.ficsitOrange)
                }
            }
        }
    }
    
    // --- SOUS-VUES ---
    
    private var headerView: some View {
        Text("GESTION DE PRODUCTION").font(.system(.headline, design: .monospaced)).foregroundColor(.ficsitOrange)
    }
    
    private var inputSection: some View {
        HStack {
            Button(action: { showSearchSheet = true }) {
                HStack {
                    if let item = selectedItem { Text(item.name).foregroundColor(.white).lineLimit(1) } else { Text("Sélectionner Pièce...").foregroundColor(.gray) }
                    Spacer(); Image(systemName: "magnifyingglass").foregroundColor(.gray)
                }.padding(10).background(Color.ficsitOrange.opacity(0.2)).cornerRadius(5).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ficsitOrange, lineWidth: 1))
            }.sheet(isPresented: $showSearchSheet) { ItemSelectorView(title: "Choisir Produit", items: db.items.filter { $0.category == "Part" }, selection: $selectedItem) }
            
            TextField("1.0", text: $ratioStr).keyboardType(.decimalPad).padding(10).frame(width: 70).background(Color.black.opacity(0.5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ficsitOrange, lineWidth: 1)).foregroundColor(.white)
            
            Button(action: { if let item = selectedItem, let ratio = Double(ratioStr) { viewModel.addGoal(item: item, ratio: ratio); HapticManager.shared.success() } }) {
                Image(systemName: "plus").padding().background(Color.ficsitOrange).foregroundColor(.black).cornerRadius(5)
            }
        }
    }
    
    private var goalsList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(viewModel.goals) { goal in
                    Button(action: { editingGoal = goal }) {
                        HStack {
                            Text(goal.item.name).font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                            Text("x\(String(format: "%.1f", goal.ratio))").font(.system(.caption, design: .monospaced)).fontWeight(.bold).foregroundColor(.ficsitOrange)
                        }.padding(8).background(Color.gray.opacity(0.3)).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
            }.padding(.horizontal, 4)
        }.frame(height: 40)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("CALCULER") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                viewModel.maximizeProduction()
                HapticManager.shared.thud()
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
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            // Affichage des erreurs
            if let error = viewModel.lastError {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("ERREUR")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.red)
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
                .background(Color.red.opacity(0.2))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 1))
            }
            
            if !viewModel.consolidatedPlan.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack { Text("CONSO ÉLECTRIQUE"); Spacer(); Text("\(Int(viewModel.totalPower)) MW").foregroundColor(.yellow) }
                        .font(.system(.caption, design: .monospaced)).padding().background(Color.black.opacity(0.3))
                    Divider().background(Color.gray)
                    
                    // NOUVEAU : AFFICHER LES VRAIS TAUX DE PRODUCTION
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SORTIES RÉELLES").font(.system(.caption2, design: .monospaced)).fontWeight(.black).foregroundColor(.gray).padding(.top, 5)
                        ForEach(viewModel.goals) { goal in
                            HStack {
                                Text(goal.item.name).font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                                Spacer()
                                let realRate = getRealRate(for: goal)
                                Text(verbatim: "\(String(format: "%.1f", realRate))/m").foregroundColor(.ficsitOrange).font(.system(.body, design: .monospaced)).fontWeight(.bold)
                            }
                        }
                    }.padding()
                    Divider().background(Color.gray)
                    
                    let grouped = Dictionary(grouping: viewModel.consolidatedPlan, by: { $0.buildingName })
                    ForEach(grouped.keys.sorted(), id: \.self) { buildingName in
                        VStack(alignment: .leading) {
                            Text(buildingName.uppercased()).font(.system(.caption2, design: .monospaced)).fontWeight(.black).foregroundColor(.gray).padding(.horizontal).padding(.top, 10)
                            if let steps = grouped[buildingName] {
                                ForEach(steps) { step in MachineRow(step: step).padding(.horizontal) }
                            }
                        }
                    }.padding(.bottom)
                }.background(Color.white.opacity(0.02)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal)
            } else if !viewModel.goals.isEmpty {
                Text("⚠️ Ressources insuffisantes ou goulot d'étranglement détecté.").font(.system(.caption, design: .monospaced)).foregroundColor(.red).padding()
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
                    Section(header: Text("Ratio Cible")) {
                        Text(goal.item.name).foregroundColor(.gray)
                        TextField("Ratio", value: $goal.ratio, format: .number).keyboardType(.decimalPad)
                    }
                    Section {
                        Button("Supprimer Objectif") { if let index = viewModel.goals.firstIndex(where: {$0.id == goal.id}) { viewModel.removeGoal(at: IndexSet(integer: index)) }; presentationMode.wrappedValue.dismiss() }.foregroundColor(.red)
                    }
                }.scrollContentBackground(.hidden).background(Color.ficsitDark)
            }.navigationTitle("Modifier Objectif").navigationBarItems(trailing: Button("Sauver") { viewModel.updateGoal(goal: goal); presentationMode.wrappedValue.dismiss() })
        }
    }
}
