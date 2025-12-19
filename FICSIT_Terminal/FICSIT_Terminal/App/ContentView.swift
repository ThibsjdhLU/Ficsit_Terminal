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
            
            // TAB 0 : CALCULATOR (Main Work Area)
            ProductionPlannerView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Calculator"), systemImage: "function")
                }
                .tag(0)
            
            // TAB 1 : FACTORY (Projects List / Hub)
            HubDashboardView(viewModel: hubViewModel, calculatorViewModel: viewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label(Localization.translate("Factory"), systemImage: "building.2.fill")
                }
                .tag(1)
            
            // TAB 2 : TO-DO (Tasks)
            NavigationView {
                ToDoListView(viewModel: viewModel)
            }
            .tabItem {
                Label(Localization.translate("To-Do"), systemImage: "checklist")
            }
            .tag(2)
            
            // TAB 3 : DATABASE (Library)
            NavigationView {
                RecipeLibraryView(viewModel: viewModel, db: db)
            }
            .tabItem {
                Label(Localization.translate("Database"), systemImage: "book.fill")
            }
            .tag(3)
            
            // TAB 4 : SETTINGS (New)
            SettingsView()
                .tabItem {
                    Label(Localization.translate("Settings"), systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(.ficsitOrange)
        .preferredColorScheme(.dark)
        .onAppear {
            hubViewModel.delegate = viewModel
        }
    }
}
