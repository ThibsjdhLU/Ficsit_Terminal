import SwiftUI

struct OutputView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    
    @State private var showCatalog = false
    @State private var showShoppingList = false
    
    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                VStack(spacing: 0) {
                    // HEADER FIXE
                    HStack {
                        Text("PRODUCTION LINES")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.ficsitOrange)
                        Spacer()
                        Button(action: { showShoppingList = true }) {
                            Image(systemName: "cart.fill")
                                .padding(8)
                                .background(Color.ficsitOrange.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.9))
                    
                    // CONTENU
                    ScrollView {
                        VStack(spacing: 20) {
                            
                            // LISTE DES OBJECTIFS ACTIFS
                            if viewModel.goals.isEmpty {
                                VStack(spacing: 15) {
                                    Image(systemName: "cube.transparent")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("No production goals set.")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.gray)
                                    
                                    Button("OPEN CATALOG") { showCatalog = true }
                                        .buttonStyle(FicsitButtonStyle())
                                        .padding(.top)
                                }
                                .padding(.vertical, 50)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.goals) { goal in
                                        GoalRow(goal: goal, viewModel: viewModel)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // BOUTON D'AJOUT FLOTTANT (si liste non vide)
                            if !viewModel.goals.isEmpty {
                                Button(action: { showCatalog = true }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("ADD PRODUCT")
                                    }
                                }
                                .buttonStyle(FicsitButtonStyle(primary: false, color: .gray))
                                .padding(.top, 10)
                            }
                            
                            Divider().background(Color.gray.opacity(0.3)).padding(.vertical)
                            
                            // BOUTON CALCULER
                            Button(action: {
                                viewModel.maximizeProduction()
                                HapticManager.shared.thud()
                            }) {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                    Text("CALCULATE OPTIMIZATION")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FicsitButtonStyle())
                            .padding(.horizontal)
                            .disabled(viewModel.goals.isEmpty)
                            
                            // RÉSULTATS (OVERVIEW)
                            if viewModel.maxBundlesPossible > 0 {
                                ResultsOverview(viewModel: viewModel)
                                    .padding(.horizontal)
                                    .padding(.bottom, 50)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarHidden(true)
            // SHEET CATALOGUE
            .sheet(isPresented: $showCatalog) {
                ProductCatalogSheet(db: db, viewModel: viewModel)
            }
            // SHEET SHOPPING
            .sheet(isPresented: $showShoppingList) {
                ShoppingListView(viewModel: viewModel)
            }
        }
    }
}

// LIGNE D'OBJECTIF AVEC STEPPER
struct GoalRow: View {
    let goal: ProductionGoal
    @ObservedObject var viewModel: CalculatorViewModel
    
    // Binding local pour le stepper qui met à jour le modèle
    var ratioBinding: Binding<Double> {
        Binding(
            get: { goal.ratio },
            set: { newVal in
                var newGoal = goal
                newGoal.ratio = newVal
                viewModel.updateGoal(goal: newGoal)
            }
        )
    }
    
    var body: some View {
        HStack {
            ItemIcon(item: goal.item, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.item.name)
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(goal.item.category.uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Stepper Custom
            FicsitStepper(value: ratioBinding)
            
            // Delete
            Button(action: {
                if let index = viewModel.goals.firstIndex(where: {$0.id == goal.id}) {
                    withAnimation { viewModel.removeGoal(at: IndexSet(integer: index)) }
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
                    .padding(8)
            }
        }
        .padding()
        .ficsitCard()
    }
}

// CATALOGUE DE PRODUITS
struct ProductCatalogSheet: View {
    @ObservedObject var db: FICSITDatabase
    @ObservedObject var viewModel: CalculatorViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    var filteredItems: [ProductionItem] {
        let parts = db.items.filter { $0.category == "Part" }
        if searchText.isEmpty { return parts }
        return parts.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                List {
                    ForEach(filteredItems) { item in
                        Button(action: {
                            viewModel.addGoal(item: item, ratio: 1.0)
                            HapticManager.shared.success()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                ItemIcon(item: item, size: 32)
                                Text(item.name).foregroundColor(.white).font(.system(.body, design: .monospaced))
                                Spacer()
                                Image(systemName: "plus.circle").foregroundColor(.ficsitOrange)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .listStyle(PlainListStyle())
                .searchable(text: $searchText, prompt: "Search parts...")
            }
            .navigationTitle("Select Product")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

// BLOC RÉSULTATS
struct ResultsOverview: View {
    @ObservedObject var viewModel: CalculatorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "bolt.fill").foregroundColor(.yellow)
                Text("POWER USAGE")
                Spacer()
                Text("\(Int(viewModel.totalPower)) MW")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            .font(.system(.caption, design: .monospaced))
            .padding()
            .background(Color.black.opacity(0.3))
            
            Divider().background(Color.gray)
            
            let grouped = Dictionary(grouping: viewModel.consolidatedPlan, by: { $0.buildingName })
            ForEach(grouped.keys.sorted(), id: \.self) { buildingName in
                VStack(alignment: .leading) {
                    FicsitHeader(title: buildingName, icon: "gear")
                        .padding(.horizontal)
                    
                    ForEach(grouped[buildingName]!) { step in
                        MachineRow(step: step)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .ficsitCard(borderColor: .white.opacity(0.1))
    }
}
