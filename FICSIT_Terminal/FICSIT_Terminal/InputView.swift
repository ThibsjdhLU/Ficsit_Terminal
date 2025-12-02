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
                            // GROS BOUTON
                            addNodeButton
                            
                            // LISTE
                            listSection
                            
                            // BELT
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
        }
    }
    
    // SOUS-VUES
    
    private var headerView: some View {
        HStack {
            Button(action: { showProjectManager = true }) { Image(systemName: "folder.fill").font(.title2).foregroundColor(.gray) }
            Spacer(); Text("RESOURCE SURVEY").font(.system(.headline, design: .monospaced)).foregroundColor(.ficsitOrange); Spacer(); Image(systemName: "folder.fill").font(.title2).opacity(0)
        }.padding().background(Color.black.opacity(0.5))
    }
    
    private var addNodeButton: some View {
        Button(action: { showAddSheet = true; HapticManager.shared.click() }) {
            HStack {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text("ADD RESOURCE NODE").font(.system(.headline, design: .monospaced)).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity).padding()
            .background(Color.ficsitOrange.opacity(0.1)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ficsitOrange, style: StrokeStyle(lineWidth: 1, dash: [5])))
            .foregroundColor(.ficsitOrange)
        }.padding(.horizontal)
    }
    
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FicsitHeader(title: "Claimed Nodes", icon: "mappin.and.ellipse")
            if viewModel.userInputs.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "magnifyingglass.circle").font(.system(size: 40)).foregroundColor(.gray)
                    Text("No resources scanned yet.").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30).background(Color.white.opacity(0.02)).cornerRadius(10)
            } else {
                ForEach(viewModel.userInputs) { input in
                    Button(action: { editingInput = input }) {
                        HStack {
                            ItemIcon(item: ProductionItem(name: input.resourceName, category: "Raw", sinkValue: 0), size: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(input.resourceName).font(.system(.headline, design: .monospaced)).foregroundColor(.white)
                                HStack {
                                    Text(input.purity.rawValue.capitalized).font(.caption).padding(4).background(getPurityColor(input.purity).opacity(0.3)).cornerRadius(4)
                                    Text(input.miner.rawValue.uppercased()).font(.caption).padding(4).background(Color.gray.opacity(0.3)).cornerRadius(4)
                                }.foregroundColor(.white)
                            }
                            Spacer()
                            Text("\(Int(input.productionRate))/m").font(.system(.title3, design: .monospaced)).fontWeight(.bold).foregroundColor(.ficsitOrange)
                        }
                        .padding().background(Color(red: 0.15, green: 0.15, blue: 0.17)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }.onDelete(perform: viewModel.removeInput)
            }
        }.padding(.horizontal)
    }
    
    private var beltSection: some View {
        VStack {
            FicsitHeader(title: "Belt Technology", icon: "speedometer")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BeltLevel.allCases) { belt in
                        Button(action: { withAnimation { viewModel.selectedBeltLevel = belt }; HapticManager.shared.click() }) {
                            VStack { Text("Mk\(belt.rawValue.last!)").fontWeight(.bold); Text("\(Int(belt.speed))").font(.caption) }
                                .padding(.vertical, 8).padding(.horizontal, 16)
                                .background(viewModel.selectedBeltLevel == belt ? Color.ficsitOrange : Color.gray.opacity(0.2))
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

struct ResourceEditorSheet: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @Environment(\.presentationMode) var presentationMode
    
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
                        Text("RESOURCE TYPE").font(.caption).foregroundColor(.gray)
                        Button(action: { showSearch = true }) {
                            HStack {
                                if let item = selectedItem { ItemIcon(item: item, size: 30); Text(item.name).font(.title3).fontWeight(.bold) }
                                Spacer(); Image(systemName: "chevron.right").foregroundColor(.gray)
                            }.padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        }
                        .sheet(isPresented: $showSearch) {
                            ItemSelectorView(title: "Select Resource", items: db.items.filter { db.rawResources.contains($0.name) }, selection: $selectedItem)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("NODE PURITY").font(.caption).foregroundColor(.gray)
                        Picker("Purity", selection: $purity) { ForEach(NodePurity.allCases) { p in Text(p.rawValue.capitalized).tag(p) } }.pickerStyle(SegmentedPickerStyle()).colorMultiply(.ficsitOrange)
                    }
                    VStack(alignment: .leading) {
                        Text("MINER LEVEL").font(.caption).foregroundColor(.gray)
                        Picker("Miner", selection: $miner) { ForEach(MinerLevel.allCases) { m in Text(m.rawValue.uppercased()).tag(m) } }.pickerStyle(SegmentedPickerStyle()).colorMultiply(.ficsitOrange)
                    }
                    Divider().background(Color.gray)
                    HStack {
                        Text("OUTPUT RATE"); Spacer(); Text("\(Int(currentRate))/m").font(.system(size: 30, weight: .bold, design: .monospaced)).foregroundColor(.ficsitOrange)
                    }.padding().background(Color.black.opacity(0.3)).cornerRadius(10)
                    Spacer()
                }.padding()
            }
            .navigationTitle(mode == .add ? "Add Node" : "Edit Node").navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") {
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
        .onChange(of: selectedItem) { _ in if let item = selectedItem { resName = item.name } }
    }
}

// Extension pour l'égalité de l'enum
extension ResourceEditorSheet.EditorMode: Equatable {
    static func == (lhs: ResourceEditorSheet.EditorMode, rhs: ResourceEditorSheet.EditorMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add): return true
        case let (.edit(l), .edit(r)): return l.id == r.id
        default: return false
        }
    }
}
