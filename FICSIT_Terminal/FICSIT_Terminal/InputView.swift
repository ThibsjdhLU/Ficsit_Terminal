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
                ProjectManagerView(viewModel: viewModel, isPresented: $showProjectManager)
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
            Button(action: { showProjectManager = true }) { Image(systemName: "folder.fill").font(.title2).foregroundColor(.ficsitGray) }
            Spacer()
            Text(Localization.translate("RESOURCE SURVEY")).font(.system(.headline, design: .monospaced)).foregroundColor(.ficsitOrange)
            Spacer()
            Image(systemName: "folder.fill").font(.title2).opacity(0)
        }.padding().background(Color.black.opacity(0.5))
    }
    
    private var addNodeButton: some View {
        Button(action: { showAddSheet = true; HapticManager.shared.click() }) {
            HStack {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text(Localization.translate("ADD NODE")).font(.system(.headline, design: .monospaced)).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity).padding()
            .background(Color.ficsitOrange.opacity(0.1)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ficsitOrange, style: StrokeStyle(lineWidth: 1, dash: [5])))
            .foregroundColor(.ficsitOrange)
        }.padding(.horizontal)
    }
    
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FicsitHeader(title: Localization.translate("Claimed Nodes"), icon: "mappin.and.ellipse")
            if viewModel.userInputs.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "magnifyingglass.circle").font(.system(size: 40)).foregroundColor(.ficsitGray)
                    Text(Localization.translate("No scanned resources.")).font(.system(.caption, design: .monospaced)).foregroundColor(.ficsitGray)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30).background(Color.white.opacity(0.02)).cornerRadius(10)
            } else {
                ForEach(viewModel.userInputs) { input in
                    HStack {
                        Button(action: { editingInput = input }) {
                            HStack {
                                ItemIcon(item: ProductionItem(name: input.resourceName, category: "Raw", sinkValue: 0), size: 40)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(Localization.translate(input.resourceName)).font(.system(.headline, design: .monospaced)).foregroundColor(.white)
                                    HStack {
                                        Text(input.purity.rawValue.capitalized).font(.caption).padding(4).background(getPurityColor(input.purity).opacity(0.3)).cornerRadius(4)
                                        Text(input.miner.rawValue.uppercased()).font(.caption).padding(4).background(Color.ficsitGray.opacity(0.3)).cornerRadius(4)
                                    }.foregroundColor(.white)
                                }
                                Spacer()
                                Text(verbatim: "\(Int(input.productionRate))/m")
                                    .font(.system(.title3, design: .monospaced)).fontWeight(.bold).foregroundColor(.ficsitOrange)
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
    
    func getPurityColor(_ purity: NodePurity) -> Color {
        switch purity { case .pure: return .green; case .normal: return .blue; case .impure: return .gray }
    }
}

// --- MODALE UNIFIÉE ---
struct ResourceEditorSheet: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @Environment(\.presentationMode) var presentationMode
    
    // RENOMMÉ POUR ÉVITER CONFLIT
    enum EditorMode { case add; case edit(ResourceInput) }
    let mode: EditorMode
    
    @State private var resName: String
    @State private var purity: NodePurity
    @State private var miner: MinerLevel
    @State private var showSearch = false
    @State private var selectedItem: ProductionItem?
    
    init(viewModel: CalculatorViewModel, db: FICSITDatabase, mode: EditorMode) {
        self.viewModel = viewModel
        self.db = db
        self.mode = mode
        switch mode {
        case .add:
            _resName = State(initialValue: "Iron Ore"); _purity = State(initialValue: .normal); _miner = State(initialValue: .mk1); _selectedItem = State(initialValue: ProductionItem(name: "Iron Ore", category: "Raw", sinkValue: 0))
        case .edit(let input):
            _resName = State(initialValue: input.resourceName); _purity = State(initialValue: input.purity); _miner = State(initialValue: input.miner); _selectedItem = State(initialValue: ProductionItem(name: input.resourceName, category: "Raw", sinkValue: 0))
        }
    }
    
    var currentRate: Double { miner.baseExtractionRate * purity.multiplier }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                VStack(spacing: 25) {
                    VStack(alignment: .leading) {
                        Text(Localization.translate("RESOURCE TYPE")).font(.caption).foregroundColor(.ficsitGray)
                        Button(action: { showSearch = true }) {
                            HStack {
                                if let item = selectedItem { ItemIcon(item: item, size: 30); Text(item.localizedName).font(.title3).fontWeight(.bold) }
                                Spacer(); Image(systemName: "chevron.right").foregroundColor(.ficsitGray)
                            }.padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        }
                        .sheet(isPresented: $showSearch) { ItemSelectorView(title: Localization.translate("Select Resource"), items: db.items.filter { db.rawResources.contains($0.name) }, selection: $selectedItem) }
                    }
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
                    Spacer()
                }.padding()
            }
            .navigationTitle(mode == .add ? Localization.translate("Add Node") : Localization.translate("Edit Node")).navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(Localization.translate("Cancel")) { presentationMode.wrappedValue.dismiss() },
                trailing: Button(Localization.translate("Save")) {
                    if let item = selectedItem {
                        switch mode {
                        case .add: viewModel.addInput(resource: item.name, purity: purity, miner: miner)
                        case .edit(let original): var updated = original; updated.resourceName = item.name; updated.purity = purity; updated.miner = miner; viewModel.updateInput(input: updated)
                        }
                    }
                    HapticManager.shared.success(); presentationMode.wrappedValue.dismiss()
                }.fontWeight(.bold).foregroundColor(.ficsitOrange)
            )
        }
        .onChange(of: selectedItem) { _, newValue in
            if let item = newValue {
                resName = item.name
            }
        }
    }
}

// Correction de l'extension Equatable pour l'enum
extension ResourceEditorSheet.EditorMode: Equatable {
    static func == (lhs: ResourceEditorSheet.EditorMode, rhs: ResourceEditorSheet.EditorMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add): return true
        case let (.edit(l), .edit(r)): return l.id == r.id
        default: return false
        }
    }
}
