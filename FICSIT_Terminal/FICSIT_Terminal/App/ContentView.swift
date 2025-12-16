import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: CalculatorViewModel
    @StateObject var hubViewModel: HubViewModel
    @StateObject var db = FICSITDatabase.shared
    @StateObject var extractionViewModel = ExtractionViewModel()

    // Global Tab Selection State
    @State private var selectedTab = 0
    
    // Initialisation du style de la TabBar pour qu'elle fasse "Tech"
    init(worldService: WorldService) {
        _viewModel = StateObject(wrappedValue: CalculatorViewModel(worldService: worldService))
        _hubViewModel = StateObject(wrappedValue: HubViewModel(worldService: worldService))

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.ficsitDark)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.ficsitOrange)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.ficsitOrange)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // TAB 0 : THE HUB (Dashboard Global)
            // Le Hub reste le point d'entrée, mais sans TabView interne
            HubDashboardView(viewModel: hubViewModel, calculatorViewModel: viewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label(Localization.translate("HUB"), systemImage: "house.fill")
                }
                .tag(0)
            
            // TAB 1 : CALCULATOR (Active Project)
            // Groupement logique de Input / Production / Graph dans un seul onglet de travail ?
            // Pour garder l'accès rapide, on garde les onglets séparés mais on peut y accéder depuis le Hub.

            // TAB 1 : INPUTS
            InputView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Resources"), systemImage: "cube.box.fill")
                }
                .tag(1)
            
            // TAB 2 : PRODUCTION (Output Goals)
            OutputView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Factory"), systemImage: "gearshape.2.fill")
                }
                .tag(2)
            
            // TAB 3 : FLOW GRAPH (Visualization)
            FactoryFlowGraphView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Flow"), systemImage: "arrow.triangle.branch")
                }
                .tag(3)
            
            // TAB 4 : POWER PLANNER
            PowerPlannerView(viewModel: viewModel)
                .tabItem {
                    Label(Localization.translate("Power"), systemImage: "bolt.fill")
                }
                .tag(4)

            // TAB 5 : TOOLS (Library, Extraction, Blueprints)
            // Regroupement pour éviter trop d'onglets
            ToolsMenuView(viewModel: viewModel, db: db, extractionViewModel: extractionViewModel)
                .tabItem {
                    Label(Localization.translate("Tools"), systemImage: "hammer.fill")
                }
                .tag(5)
        }
        .accentColor(.ficsitOrange)
        .preferredColorScheme(.dark)
        .onAppear {
            hubViewModel.delegate = viewModel
        }
    }
}

// Nouveau Menu Outils pour regrouper Library, To-Do, Extraction, Blueprints
struct ToolsMenuView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @ObservedObject var extractionViewModel: ExtractionViewModel

    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()

                List {
                    Section(header: Text(Localization.translate("PLANNING TOOLS")).fontDesign(.monospaced)) {
                        NavigationLink(destination: RecipeLibraryView(viewModel: viewModel, db: db)) {
                            Label(Localization.translate("Library"), systemImage: "book.fill")
                        }

                        NavigationLink(destination: ToDoListView(viewModel: viewModel)) {
                            Label(Localization.translate("To-Do"), systemImage: "checklist")
                        }

                        NavigationLink(destination: ResourceExtractionView().environmentObject(extractionViewModel)) {
                            Label(Localization.translate("Extraction Calculator"), systemImage: "hammer.fill")
                        }

                        NavigationLink(destination: BlueprintListView()) {
                            Label(Localization.translate("Blueprint Library"), systemImage: "doc.text.fill")
                        }
                    }
                    .listRowBackground(Color.ficsitDark.opacity(0.8))
                }
                .scrollContentBackground(.hidden)
                .navigationTitle(Localization.translate("Tools"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
