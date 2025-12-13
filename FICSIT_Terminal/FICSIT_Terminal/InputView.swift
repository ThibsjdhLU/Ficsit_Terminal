import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    
    // États UI
    @State private var showProjectManager = false
    @State private var showAddSheet = false
    @State private var editingInput: ResourceInput?
    
    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                VStack(spacing: 0) {
                    headerView
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            addNodeButton
                            listSection
                            beltSection
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showProjectManager) {
                // Legacy, peut-être remplacé par un redirect au Hub
                Text("Use Hub to switch factories")
            }
            .sheet(isPresented: $showAddSheet) {
                ResourceEditorSheet(viewModel: viewModel, db: db, mode: .add)
            }
            .sheet(item: $editingInput) { input in
                ResourceEditorSheet(viewModel: viewModel, db: db, mode: .edit(input))
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .foregroundColor(.ficsitOrange)
                }
            }
        }
    }
    
    // --- SOUS-VUES ---
    
    private var headerView: some View {
        HStack {
            Spacer()
            Text(Localization.translate("RESOURCE SURVEY")).font(.system(.headline, design: .monospaced)).foregroundColor(.ficsitOrange)
            Spacer()
        }.padding().background(Color.black.opacity(0.5))
    }
    
    private var addNodeButton: some View {
        Button(action: { showAddSheet = true; HapticManager.shared.click() }) {
            HStack {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text(Localization.translate("ADD SOURCE")).font(.system(.headline, design: .monospaced)).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity).padding()
            .background(Color.ficsitOrange.opacity(0.1)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ficsitOrange, style: StrokeStyle(lineWidth: 1, dash: [5])))
            .foregroundColor(.ficsitOrange)
        }.padding(.horizontal)
    }
    
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FicsitHeader(title: Localization.translate("Claimed Sources"), icon: "mappin.and.ellipse")
            if viewModel.userInputs.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "magnifyingglass.circle").font(.system(size: 40)).foregroundColor(.ficsitGray)
                    Text(Localization.translate("No resources configured.")).font(.system(.caption, design: .monospaced)).foregroundColor(.ficsitGray)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30).background(Color.white.opacity(0.02)).cornerRadius(10)
            } else {
                ForEach(viewModel.userInputs) { input in
                    InputCard(input: input, viewModel: viewModel) {
                        editingInput = input
                    }
                }
            }
        }.padding(.horizontal)
    }
    
    private var beltSection: some View {
        VStack {
            FicsitHeader(title: Localization.translate("Belt Level"), icon: "speedometer")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BeltLevel.allCases) { belt in
                        Button(action: { withAnimation { viewModel.selectedBeltLevel = belt }; HapticManager.shared.click() }) {
                            VStack {
                                Text("Mk\(String(belt.rawValue.suffix(1)))").fontWeight(.bold)
                                Text("\(Int(belt.speed))").font(.caption)
                            }
                                .padding(.vertical, 8).padding(.horizontal, 16)
                                .background(viewModel.selectedBeltLevel == belt ? Color.ficsitOrange : Color.ficsitGray.opacity(0.2))
                                .foregroundColor(viewModel.selectedBeltLevel == belt ? .black : .white).cornerRadius(8)
                        }
                    }
                }.padding(.horizontal)
            }
        }.padding(.bottom)
    }
}

// --- SOUS-VUE CARTE INPUT ---
struct InputCard: View {
    let input: ResourceInput
    @ObservedObject var viewModel: CalculatorViewModel
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Button(action: onEdit) {
                HStack {
                    ItemIcon(item: ProductionItem(name: input.resourceName, category: "Raw", sinkValue: 0), size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Localization.translate(input.resourceName)).font(.system(.headline, design: .monospaced)).foregroundColor(.white)

                        // Badge Source Type
                        switch input.sourceType {
                        case .node(let purity, let miner):
                            HStack {
                                Text(purity.rawValue.capitalized).font(.caption).padding(4).background(getPurityColor(purity).opacity(0.3)).cornerRadius(4)
                                Text(miner.rawValue.uppercased()).font(.caption).padding(4).background(Color.ficsitGray.opacity(0.3)).cornerRadius(4)
                            }.foregroundColor(.white)
                        case .factory(let id):
                            HStack {
                                Image(systemName: "building.2.fill").font(.caption)
                                Text(getFactoryName(id: id)).font(.caption)
                            }
                            .padding(4)
                            .background(Color.purple.opacity(0.3))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                        }
                    }
                    Spacer()
                    // Si c'est un node, on affiche le taux
                    if case .node = input.sourceType {
                        Text(verbatim: "\(Int(input.productionRate))/m")
                            .font(.system(.title3, design: .monospaced)).fontWeight(.bold).foregroundColor(.ficsitOrange)
                    } else {
                         Text("Import")
                            .font(.system(.caption, design: .monospaced)).foregroundColor(.ficsitGray)
                    }
                }
                .padding().background(Color.ficsitDark).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                if let index = viewModel.userInputs.firstIndex(where: { $0.id == input.id }) {
                    viewModel.removeInput(at: IndexSet(integer: index))
                    HapticManager.shared.click()
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3))
                    .padding(8)
            }
        }
    }
    
    func getPurityColor(_ purity: NodePurity) -> Color {
        switch purity { case .pure: return .green; case .normal: return .blue; case .impure: return .gray }
    }

    func getFactoryName(id: UUID) -> String {
        return viewModel.worldService.getFactory(id: id)?.name ?? "Unknown Factory"
    }
}

// --- MODALE UNIFIÉE ---
struct ResourceEditorSheet: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @Environment(\.presentationMode) var presentationMode
    
    // Mode
    enum EditorMode: Equatable { case add; case edit(ResourceInput) }
    let mode: EditorMode
    
    // State Source
    enum SourceMode: String, CaseIterable {
        case node = "Resource Node"
        case logistics = "Logistics Import"
    }
    @State private var sourceMode: SourceMode = .node

    // State Node
    @State private var resName: String
    @State private var purity: NodePurity
    @State private var miner: MinerLevel
    @State private var showSearch = false
    @State private var selectedItem: ProductionItem?
    
    // State Logistics
    @State private var selectedFactoryId: UUID?

    init(viewModel: CalculatorViewModel, db: FICSITDatabase, mode: EditorMode) {
        self.viewModel = viewModel
        self.db = db
        self.mode = mode

        switch mode {
        case .add:
            _resName = State(initialValue: "Iron Ore")
            _purity = State(initialValue: .normal)
            _miner = State(initialValue: .mk1)
            _selectedItem = State(initialValue: ProductionItem(name: "Iron Ore", category: "Raw", sinkValue: 0))
            _sourceMode = State(initialValue: .node)
        case .edit(let input):
            _resName = State(initialValue: input.resourceName)
            switch input.sourceType {
            case .node(let p, let m):
                _purity = State(initialValue: p)
                _miner = State(initialValue: m)
                _sourceMode = State(initialValue: .node)
            case .factory(let id):
                _purity = State(initialValue: .normal)
                _miner = State(initialValue: .mk1)
                _sourceMode = State(initialValue: .logistics)
                _selectedFactoryId = State(initialValue: id)
            }
            _selectedItem = State(initialValue: ProductionItem(name: input.resourceName, category: "Raw", sinkValue: 0))
        }
    }
    
    var currentRate: Double { miner.baseExtractionRate * purity.multiplier }
    
    var availableFactories: [Factory] {
        // Exclure l'usine courante pour éviter l'auto-référence (pour l'instant, pas de boucle directe)
        viewModel.worldService.world.factories.filter { $0.id != viewModel.currentProjectId }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                VStack(spacing: 25) {

                    // Toggle Source Type
                    Picker("Source", selection: $sourceMode) {
                        ForEach(SourceMode.allCases, id: \.self) { mode in
                            Text(Localization.translate(mode.rawValue)).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    // Resource Selector (Common)
                    VStack(alignment: .leading) {
                        Text(Localization.translate("RESOURCE TYPE")).font(.caption).foregroundColor(.ficsitGray)
                        Button(action: { showSearch = true }) {
                            HStack {
                                if let item = selectedItem { ItemIcon(item: item, size: 30); Text(item.localizedName).font(.title3).fontWeight(.bold) }
                                Spacer(); Image(systemName: "chevron.right").foregroundColor(.ficsitGray)
                            }.padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        }
                        .sheet(isPresented: $showSearch) {
                            // En mode Node : Seulement rawResources
                            // En mode Logistique : Tout sauf rawResources (ou tout court ?) -> Disons Raw + Parts
                            let filter: (ProductionItem) -> Bool = (sourceMode == .node)
                                ? { db.rawResources.contains($0.name) }
                                : { _ in true }

                            ItemSelectorView(title: Localization.translate("Select Resource"), items: db.items.filter(filter), selection: $selectedItem)
                        }
                    }

                    if sourceMode == .node {
                        // --- NODE EDITOR ---
                        VStack(alignment: .leading) {
                            Text(Localization.translate("NODE PURITY")).font(.caption).foregroundColor(.ficsitGray)
                            Picker("Purity", selection: $purity) { ForEach(NodePurity.allCases) { p in Text(p.rawValue.capitalized).tag(p) } }.pickerStyle(SegmentedPickerStyle()).colorMultiply(.ficsitOrange)
                        }
                        VStack(alignment: .leading) {
                            Text(Localization.translate("MINER LEVEL")).font(.caption).foregroundColor(.ficsitGray)
                            Picker("Miner", selection: $miner) { ForEach(MinerLevel.allCases) { m in Text(m.rawValue.uppercased()).tag(m) } }.pickerStyle(SegmentedPickerStyle()).colorMultiply(.ficsitOrange)
                        }
                        Divider().background(Color.ficsitGray)
                        HStack {
                            Text(Localization.translate("EXTRACTION RATE")); Spacer(); Text("\(Int(currentRate))/m").font(.system(size: 30, weight: .bold, design: .monospaced)).foregroundColor(.ficsitOrange)
                        }.padding().background(Color.black.opacity(0.3)).cornerRadius(10)

                    } else {
                        // --- LOGISTICS EDITOR ---
                        VStack(alignment: .leading) {
                            Text(Localization.translate("SOURCE FACTORY")).font(.caption).foregroundColor(.ficsitGray)

                            if availableFactories.isEmpty {
                                Text(Localization.translate("No other factories available."))
                                    .foregroundColor(.ficsitGray)
                                    .padding()
                            } else {
                                Menu {
                                    ForEach(availableFactories) { factory in
                                        Button(action: { selectedFactoryId = factory.id }) {
                                            HStack {
                                                if selectedFactoryId == factory.id { Image(systemName: "checkmark") }
                                                Text(factory.name)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedFactoryId == nil ? Localization.translate("Select Factory...") : (availableFactories.first(where: {$0.id == selectedFactoryId})?.name ?? "Unknown"))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "chevron.down").foregroundColor(.ficsitGray)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }

                        Divider().background(Color.ficsitGray)

                        Text(Localization.translate("This will import resources produced by the selected factory."))
                            .font(.caption)
                            .foregroundColor(.ficsitGray)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }.padding()
            }
            .navigationTitle(mode == .add ? Localization.translate("Add Source") : Localization.translate("Edit Source")).navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(Localization.translate("Cancel")) { presentationMode.wrappedValue.dismiss() },
                trailing: Button(Localization.translate("Save")) {
                    saveInput()
                    HapticManager.shared.success(); presentationMode.wrappedValue.dismiss()
                }.fontWeight(.bold).foregroundColor(.ficsitOrange)
                 .disabled(sourceMode == .logistics && selectedFactoryId == nil)
            )
        }
        .onChange(of: selectedItem) { _, newValue in
            if let item = newValue {
                resName = item.name
            }
        }
    }

    private func saveInput() {
        guard let item = selectedItem else { return }

        if sourceMode == .node {
            switch mode {
            case .add: viewModel.addInput(resource: item.name, purity: purity, miner: miner)
            case .edit(let original):
                var updated = original
                updated.resourceName = item.name
                updated.sourceType = .node(purity: purity, miner: miner)
                viewModel.updateInput(input: updated)
            }
        } else {
            guard let factoryId = selectedFactoryId else { return }
            switch mode {
            case .add: viewModel.addImportInput(resource: item.name, fromFactoryID: factoryId)
            case .edit(let original):
                var updated = original
                updated.resourceName = item.name
                updated.sourceType = .factory(id: factoryId)
                viewModel.updateInput(input: updated)
            }
        }
    }
}
