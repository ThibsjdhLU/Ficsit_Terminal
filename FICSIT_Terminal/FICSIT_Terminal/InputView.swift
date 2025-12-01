import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    
    // États UI
    @State private var showProjectManager = false
    @State private var showAddSheet = false
    @State private var editingInput: ResourceInput? // Pour modifier un existant
    
    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                VStack(spacing: 0) {
                    headerView
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // NOUVEAU : Gros bouton d'action
                            addNodeButton
                            
                            // Liste des nœuds existants
                            listSection
                            
                            // Réglages globaux (Tapis)
                            beltSection
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarHidden(true)
            // Gestion des Modales (Sheets)
            .sheet(isPresented: $showProjectManager) {
                ProjectManagerView(viewModel: viewModel, isPresented: $showProjectManager)
            }
            // Modale d'AJOUT
            .sheet(isPresented: $showAddSheet) {
                ResourceEditorSheet(viewModel: viewModel, db: db, mode: .add)
            }
            // Modale d'ÉDITION (déclenchée quand editingInput n'est pas nil)
            .sheet(item: $editingInput) { input in
                ResourceEditorSheet(viewModel: viewModel, db: db, mode: .edit(input))
            }
        }
    }
    
    // --- SOUS-VUES ---
    
    private var headerView: some View {
        HStack {
            Button(action: { showProjectManager = true }) {
                Image(systemName: "folder.fill").font(.title2).foregroundColor(.gray)
            }
            Spacer()
            Text("RESOURCE SURVEY").font(.system(.headline, design: .monospaced)).foregroundColor(.ficsitOrange)
            Spacer()
            Image(systemName: "folder.fill").font(.title2).opacity(0)
        }
        .padding().background(Color.black.opacity(0.5))
    }
    
    private var addNodeButton: some View {
        Button(action: {
            showAddSheet = true
            HapticManager.shared.click()
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("ADD RESOURCE NODE")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.ficsitOrange.opacity(0.1)) // Fond léger
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.ficsitOrange, style: StrokeStyle(lineWidth: 1, dash: [5])) // Bordure pointillée "Tech"
            )
            .foregroundColor(.ficsitOrange)
        }
        .padding(.horizontal)
    }
    
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FicsitHeader(title: "Claimed Nodes", icon: "mappin.and.ellipse")
            
            if viewModel.userInputs.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No resources scanned yet.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.02))
                .cornerRadius(10)
            } else {
                ForEach(viewModel.userInputs) { input in
                    Button(action: { editingInput = input }) {
                        HStack {
                            ItemIcon(item: ProductionItem(name: input.resourceName, category: "Raw", sinkValue: 0), size: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(input.resourceName)
                                    .font(.system(.headline, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                HStack {
                                    // Badges pour Pureté et Miner
                                    Text(input.purity.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(4)
                                        .background(getPurityColor(input.purity).opacity(0.3))
                                        .cornerRadius(4)
                                    
                                    Text(input.miner.rawValue.uppercased())
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(4)
                                }
                                .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Débit (CORRECTION DU WARNING ICI AVEC 'verbatim')
                            Text(verbatim: "\(Int(input.productionRate))/m")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.ficsitOrange)
                        }
                        .padding()
                        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .onDelete(perform: viewModel.removeInput)
            }
        }
        .padding(.horizontal)
    }
    
    private var beltSection: some View {
        VStack {
            FicsitHeader(title: "Belt Technology", icon: "speedometer")
            
            // Picker Horizontal Custom
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BeltLevel.allCases) { belt in
                        Button(action: {
                            withAnimation { viewModel.selectedBeltLevel = belt }
                            HapticManager.shared.click()
                        }) {
                            VStack {
                                Text("Mk\(belt.rawValue.last!)")
                                    .fontWeight(.bold)
                                Text("\(Int(belt.speed))")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(viewModel.selectedBeltLevel == belt ? Color.ficsitOrange : Color.gray.opacity(0.2))
                            .foregroundColor(viewModel.selectedBeltLevel == belt ? .black : .white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    func getPurityColor(_ purity: NodePurity) -> Color {
        switch purity {
        case .pure: return .green
        case .normal: return .blue
        case .impure: return .gray
        }
    }
}

// --- NOUVELLE SHEET UNIFIÉE (ADD/EDIT) ---
struct ResourceEditorSheet: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @Environment(\.presentationMode) var presentationMode
    
    // CORRECTION : Renommage de Mode -> EditorMode pour éviter le conflit de nom
    enum EditorMode {
        case add
        case edit(ResourceInput)
    }
    
    let mode: EditorMode
    
    // États locaux pour le formulaire
    @State private var resName: String
    @State private var purity: NodePurity
    @State private var miner: MinerLevel
    
    init(viewModel: CalculatorViewModel, db: FICSITDatabase, mode: EditorMode) {
        self.viewModel = viewModel
        self.db = db
        self.mode = mode
        
        switch mode {
        case .add:
            _resName = State(initialValue: "Iron Ore")
            _purity = State(initialValue: .normal)
            _miner = State(initialValue: .mk1)
        case .edit(let input):
            _resName = State(initialValue: input.resourceName)
            _purity = State(initialValue: input.purity)
            _miner = State(initialValue: input.miner)
        }
    }
    
    var currentRate: Double {
        miner.baseExtractionRate * purity.multiplier
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                
                VStack(spacing: 25) {
                    
                    // SÉLECTEUR RESSOURCE
                    VStack(alignment: .leading) {
                        Text("RESOURCE TYPE").font(.caption).foregroundColor(.gray)
                        Menu {
                            ForEach(db.rawResources, id: \.self) { r in
                                Button(r) { resName = r }
                            }
                        } label: {
                            HStack {
                                ItemIcon(item: ProductionItem(name: resName, category: "Raw", sinkValue: 0), size: 30)
                                Text(resName).font(.title3).fontWeight(.bold)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        }
                    }
                    
                    // SÉLECTEUR PURETÉ
                    VStack(alignment: .leading) {
                        Text("NODE PURITY").font(.caption).foregroundColor(.gray)
                        Picker("Purity", selection: $purity) {
                            ForEach(NodePurity.allCases) { p in
                                Text(p.rawValue.capitalized).tag(p)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .colorMultiply(.ficsitOrange)
                    }
                    
                    // SÉLECTEUR MINER
                    VStack(alignment: .leading) {
                        Text("MINER LEVEL").font(.caption).foregroundColor(.gray)
                        Picker("Miner", selection: $miner) {
                            ForEach(MinerLevel.allCases) { m in
                                Text(m.rawValue.uppercased()).tag(m)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .colorMultiply(.ficsitOrange)
                    }
                    
                    Divider().background(Color.gray)
                    
                    // APERÇU CALCUL
                    HStack {
                        Text("OUTPUT RATE")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(currentRate))/m")
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .foregroundColor(.ficsitOrange)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") {
                    save()
                    HapticManager.shared.success()
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(.ficsitOrange)
            )
        }
    }
    
    var modeTitle: String {
        switch mode {
        case .add: return "Add Node"
        case .edit: return "Edit Node"
        }
    }
    
    func save() {
        switch mode {
        case .add:
            viewModel.addInput(resource: resName, purity: purity, miner: miner)
        case .edit(let original):
            // Création d'une copie modifiée
            var updated = original
            updated.resourceName = resName
            updated.purity = purity
            updated.miner = miner
            viewModel.updateInput(input: updated)
        }
    }
}
