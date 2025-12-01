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
                    // 1. ZONE SUPÉRIEURE (FIXE)
                    VStack(spacing: 15) {
                        headerView
                        inputSection
                        goalsList
                        actionButtons
                    }
                    .padding()
                    .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                    .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.1)), alignment: .bottom)
                    
                    // 2. RÉSULTATS (SCROLLABLE)
                    ScrollView {
                        resultsSection
                            .padding(.vertical)
                    }
                }
            }
            .navigationBarHidden(true)
            // MODALES
            .sheet(item: $editingGoal) { goal in
                EditGoalSheet(goal: goal, viewModel: viewModel)
            }
            .sheet(isPresented: $showShoppingList) {
                ShoppingListView(viewModel: viewModel)
            }
            // CLAVIER
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.ficsitOrange)
                }
            }
        }
    }
    
    // --- SOUS-VUES ---
    
    private var headerView: some View {
        Text("PRODUCTION MANAGER")
            .font(.system(.headline, design: .monospaced))
            .foregroundColor(.ficsitOrange)
    }
    
    private var inputSection: some View {
        HStack {
            // SELECTEUR ITEM
            Button(action: { showSearchSheet = true }) {
                HStack {
                    if let item = selectedItem {
                        Text(item.name).foregroundColor(.white).lineLimit(1)
                    } else {
                        Text("Select Part...").foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.ficsitOrange.opacity(0.2)) // Légère teinte
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ficsitOrange, lineWidth: 1))
            }
            .sheet(isPresented: $showSearchSheet) {
                ItemSelectorView(title: "Select Product", items: db.items.filter { $0.category == "Part" }, selection: $selectedItem)
            }
            
            // RATIO
            TextField("1.0", text: $ratioStr)
                .keyboardType(.decimalPad)
                .padding(10)
                .frame(width: 70)
                .background(Color.black.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ficsitOrange, lineWidth: 1))
                .foregroundColor(.white)
            
            // BOUTON ADD
            Button(action: {
                if let item = selectedItem, let ratio = Double(ratioStr) {
                    viewModel.addGoal(item: item, ratio: ratio)
                    HapticManager.shared.success()
                }
            }) {
                Image(systemName: "plus")
                    .padding()
                    .background(Color.ficsitOrange)
                    .foregroundColor(.black)
                    .cornerRadius(5)
            }
        }
    }
    
    private var goalsList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(viewModel.goals) { goal in
                    Button(action: { editingGoal = goal }) {
                        HStack {
                            Text(goal.item.name)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                            Text("x\(String(format: "%.1f", goal.ratio))")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.ficsitOrange)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
        .frame(height: 40)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("CALCULATE") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                viewModel.maximizeProduction()
                HapticManager.shared.thud()
            }
            .buttonStyle(FicsitButtonStyle())
            
            Button(action: { showShoppingList = true }) {
                Image(systemName: "cart.fill")
            }
            .buttonStyle(FicsitButtonStyle(primary: false, color: .white))
            .frame(width: 60)
        }
    }
    
    private var resultsSection: some View {
        VStack(spacing: 20) {
            if viewModel.maxBundlesPossible > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Résultat
                    HStack {
                        Text("POWER DRAW")
                        Spacer()
                        Text("\(Int(viewModel.totalPower)) MW").foregroundColor(.yellow)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.black.opacity(0.3))
                    
                    Divider().background(Color.gray)
                    
                    // Liste des Machines
                    let grouped = Dictionary(grouping: viewModel.consolidatedPlan, by: { $0.buildingName })
                    ForEach(grouped.keys.sorted(), id: \.self) { buildingName in
                        VStack(alignment: .leading) {
                            Text(buildingName.uppercased())
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                            ForEach(grouped[buildingName]!) { step in
                                MachineRow(step: step)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom)
                }
                .background(Color.white.opacity(0.02))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal)
            } else if !viewModel.goals.isEmpty {
                Text("⚠️ Insufficient resources or bottleneck detected.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
}

// STRUCT MANQUANTE : EDIT GOAL SHEET
struct EditGoalSheet: View {
    @State var goal: ProductionGoal
    @ObservedObject var viewModel: CalculatorViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                Form {
                    Section(header: Text("Target Ratio")) {
                        Text(goal.item.name).foregroundColor(.gray)
                        TextField("Ratio", value: $goal.ratio, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    Section {
                        Button("Delete Goal") {
                            if let index = viewModel.goals.firstIndex(where: {$0.id == goal.id}) {
                                viewModel.removeGoal(at: IndexSet(integer: index))
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.ficsitDark)
            }
            .navigationTitle("Edit Goal")
            .navigationBarItems(trailing: Button("Save") {
                viewModel.updateGoal(goal: goal)
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
