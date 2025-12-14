import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: CalculatorViewModel
    @StateObject var hubViewModel: HubViewModel
    @StateObject var db = FICSITDatabase.shared
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
            
            // TAB 0 : THE HUB (Dashboard)
            HubDashboardView(viewModel: hubViewModel, calculatorViewModel: viewModel)
                .tabItem {
                    Label(Localization.translate("HUB"), systemImage: "house.fill")
                }
                .tag(0)
            
            // TAB : TO-DO LIST
            ToDoListView(viewModel: viewModel)
                .tabItem {
                    Label(Localization.translate("To-Do"), systemImage: "checklist")
                }
                .tag(6)

            // TAB 1 : RESOURCES
            InputView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Resources"), systemImage: "cube.box.fill")
                }
                .tag(1)
            
            // TAB 2 : PRODUCTION
            OutputView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Factory"), systemImage: "gearshape.2.fill")
                }
                .tag(2)
            
            // TAB 3 : POWER
            PowerPlannerView(viewModel: viewModel)
                .tabItem {
                    Label(Localization.translate("Power"), systemImage: "bolt.fill")
                }
                .tag(3)
            
            // TAB 4 : LIBRARY
            RecipeLibraryView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Library"), systemImage: "book.fill")
                }
                .tag(4)
            
            // TAB 5 : FLOW GRAPH
            FactoryFlowGraphView(viewModel: viewModel, db: db)
                .tabItem {
                    Label(Localization.translate("Flow"), systemImage: "arrow.triangle.branch")
                }
                .tag(5)
        }
        .accentColor(.ficsitOrange)
        .preferredColorScheme(.dark)
    }
}
