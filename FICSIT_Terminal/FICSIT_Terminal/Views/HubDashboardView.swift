import SwiftUI

struct HubDashboardView: View {
    @StateObject var viewModel: HubViewModel
    @ObservedObject var calculatorViewModel: CalculatorViewModel
    @StateObject var extractionViewModel = ExtractionViewModel()

    // Tab State
    @State private var selectedTab: Int = 1
    
    // Search State (Global)
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [ProductionItem] = []

    init(viewModel: HubViewModel, calculatorViewModel: CalculatorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.calculatorViewModel = calculatorViewModel

        // Custom Tab Bar Appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        appearance.selectionIndicatorTintColor = UIColor(red: 250/255, green: 149/255, blue: 73/255, alpha: 1.0)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {

                // TAB 1: FACTORY DASHBOARD (Overview)
                FactoryDashboardTab(viewModel: viewModel, calculatorViewModel: calculatorViewModel, selectedTab: $selectedTab)
                    .tabItem {
                        Label("Factory", systemImage: "building.2.fill")
                    }
                    .tag(1)

                // TAB 2: CALCULATOR (Active Project)
                if !calculatorViewModel.currentProjectId.isEmpty {
                    NavigationView {
                        CalculatorView(viewModel: calculatorViewModel)
                    }
                    .tabItem {
                        Label("Calculator", systemImage: "function")
                    }
                    .tag(2)
                } else {
                    Text("Select a factory to open Calculator")
                        .tabItem { Label("Calculator", systemImage: "function") }
                        .tag(2)
                }

                // TAB 3: BLUEPRINTS & EXTRACTION (Tools)
                NavigationView {
                    ToolsView()
                        .environmentObject(extractionViewModel)
                }
                .tabItem {
                    Label("Tools", systemImage: "hammer.fill")
                }
                .tag(3)

                // TAB 4: DATABASE
                NavigationView {
                    DatabaseView()
                }
                .tabItem {
                    Label("Database", systemImage: "internaldrive.fill")
                }
                .tag(4)

                // TAB 5: TO-DO
                NavigationView {
                    ToDoListView(viewModel: calculatorViewModel)
                }
                .tabItem {
                    Label("To-Do", systemImage: "checkmark.square.fill")
                }
                .tag(5)
            }
            .accentColor(.ficsitOrange)
        }
        .onAppear {
            viewModel.delegate = calculatorViewModel
        }
    }
}

// MARK: - SUB-VIEWS FOR TABS

struct FactoryDashboardTab: View {
    @ObservedObject var viewModel: HubViewModel
    @ObservedObject var calculatorViewModel: CalculatorViewModel
    @Binding var selectedTab: Int

    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // HEADER
                        HStack {
                            VStack(alignment: .leading) {
                                Text("FICSIT OS")
                                    .font(.caption).fontDesign(.monospaced)
                                    .foregroundColor(.ficsitOrange)
                                Text("DASHBOARD")
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
                                    Text("CURRENT PROJECT")
                                        .font(.caption).bold().foregroundColor(.ficsitOrange)
                                    Spacer()
                                    Text("ONLINE")
                                        .font(.caption).bold()
                                        .padding(4)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }

                                Text(current.name)
                                    .font(.title).bold().fontDesign(.monospaced)

                                HStack {
                                    Label("\(current.goals.count) Goals", systemImage: "target")
                                    Spacer()
                                    Label("\(current.inputs.count) Inputs", systemImage: "arrow.down.circle")
                                }
                                .font(.subheadline).foregroundColor(.gray)

                                Divider().background(Color.gray)

                                Button(action: {
                                    selectedTab = 2 // Switch to Calculator
                                    HapticManager.shared.click()
                                }) {
                                    Text("Open Calculator")
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
                        }

                        // FACTORY LIST
                        VStack(alignment: .leading) {
                            HStack {
                                Text("ALL PROJECTS")
                                    .font(.headline).fontDesign(.monospaced)
                                Spacer()
                                Button(action: { viewModel.showingCreateAlert = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.ficsitOrange)
                                }
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
            .alert("New Project", isPresented: $viewModel.showingCreateAlert) {
                TextField("Project Name", text: $viewModel.newFactoryName)
                Button("Cancel", role: .cancel) { }
                Button("Create") { viewModel.createNewFactory() }
            }
            .navigationBarHidden(true)
        }
    }
}

struct ToolsView: View {
    var body: some View {
        ZStack {
            FicsitBackground()
            List {
                Section(header: Text("PLANNING TOOLS").fontDesign(.monospaced)) {
                    NavigationLink(destination: ResourceExtractionView()) {
                        Label("Extraction Calculator", systemImage: "hammer.fill")
                    }

                    NavigationLink(destination: BlueprintListView()) {
                        Label("Blueprint Library", systemImage: "doc.text.fill")
                    }

                    NavigationLink(destination: Text("Coming Soon: Logistics")) {
                        Label("Logistics Planner", systemImage: "arrow.triangle.branch")
                    }
                    .padding(.bottom, 20)
                }
                .listRowBackground(Color.ficsitDark.opacity(0.8))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DatabaseView: View {
    @State private var searchText = ""
    @StateObject private var db = FICSITDatabase.shared

    var filteredItems: [ProductionItem] {
        if searchText.isEmpty { return db.items }
        return db.items.filter { $0.localizedName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            FicsitBackground()
            VStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search Items & Recipes...", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.ficsitDark)
                .cornerRadius(8)
                .padding()

                List {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: RecipeDetailViewWrapper(item: item)) {
                            HStack {
                                ItemIcon(item: item, size: 32)
                                Text(item.localizedName)
                            }
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.3))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Database")
        .navigationBarHidden(true)
    }
}

struct RecipeDetailViewWrapper: View {
    let item: ProductionItem
    var body: some View {
        if let recipe = FICSITDatabase.shared.getRecipesOptimized(producing: item.name).first {
            RecipeDetailView(recipe: recipe)
        } else {
            Text("Raw Resource: \(item.localizedName)")
                .ficsitBackground()
        }
    }
}

struct FactoryListCard: View {
    let factory: Factory
    let isActive: Bool
    
    var body: some View {
        // Reuse existing logic or create simple view
        if let recipe = FICSITDatabase.shared.getRecipesOptimized(producing: item.name).first {
            RecipeDetailView(recipe: recipe)
        } else {
            Text("Raw Resource: \(item.localizedName)")
                .ficsitBackground()
        }
    }
}
