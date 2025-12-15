import SwiftUI

// MARK: - Vue Principale du Graphique de Flux
struct FactoryFlowGraphView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @State private var zoomScale: CGFloat = 1.0
    @State private var selectedNode: GraphNode?
    @State private var selectedLink: GraphLink?
    @State private var isCompactMode: Bool = false
    @State private var showMiniMap: Bool = false
    @State private var cachedLayout: GraphEngine.GraphLayout?
    
    private let graphEngine = GraphEngine()
    private let bottleneckDetector = BottleneckDetector()
    
    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                VStack(spacing: 0) {
                    // Header avec énergie totale et contrôles
                    headerView
                    
                    // Zone de graphique avec zoom et scroll
                    if viewModel.consolidatedPlan.isEmpty {
                        emptyStateView
                    } else {
                        graphContentView
                            .onChange(of: viewModel.consolidatedPlan.count) { _, _ in
                                // Invalider le cache quand le plan change
                                cachedLayout = nil
                            }
                            .onChange(of: viewModel.userInputs.count) { _, _ in
                                cachedLayout = nil
                            }
                            .onChange(of: viewModel.goals.count) { _, _ in
                                cachedLayout = nil
                            }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedNode) { node in
                MachineDetailSheet(node: node, viewModel: viewModel, db: db)
            }
            .sheet(item: $selectedLink) { link in
                LinkDetailSheet(link: link, layout: graphLayout)
            }
        }
    }
    
    // MARK: - Layout du Graphique
    private var graphLayout: GraphEngine.GraphLayout {
        if let layout = cachedLayout {
            return layout
        }
        return graphEngine.generateLayout(
            from: viewModel.consolidatedPlan,
            inputs: viewModel.userInputs,
            goals: viewModel.goals,
            sinkResult: viewModel.sinkResult,
            db: db
        )
    }

    private func updateLayout() {
        // Exécuter la génération sur le thread principal car cela touche l'UI,
        // mais idéalement cela devrait être déporté si c'est très lourd.
        // Pour l'instant, on optimise surtout les re-renders (zoom/scroll).
        cachedLayout = graphEngine.generateLayout(
            from: viewModel.consolidatedPlan,
            inputs: viewModel.userInputs,
            goals: viewModel.goals,
            sinkResult: viewModel.sinkResult,
            db: db
        )
    }
    
    // MARK: - Bottlenecks
    private var bottlenecks: [Bottleneck] {
        bottleneckDetector.detectBottlenecks(
            goals: viewModel.goals,
            inputs: viewModel.userInputs,
            beltLimit: viewModel.selectedBeltLevel.speed,
            activeRecipes: viewModel.activeRecipes,
            consolidatedPlan: viewModel.consolidatedPlan
        )
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BLUEPRINT USINE")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.ficsitOrange)
                    Text("Diagramme de Flux")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.ficsitGray)
                }
                
                Spacer()
                
                // Statistiques
                HStack(spacing: 12) {
                    // Énergie totale
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                        Text("\(Int(viewModel.totalPower)) MW")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.ficsitOrange.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Machines totales
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.ficsitGray)
                            .font(.system(size: 10))
                        Text("\(viewModel.consolidatedPlan.count) machines")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Contrôles
                HStack(spacing: 8) {
                    Button(action: { isCompactMode.toggle() }) {
                        Image(systemName: isCompactMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.blue.opacity(0.7))
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button(action: { showMiniMap.toggle() }) {
                        Image(systemName: showMiniMap ? "map.fill" : "map")
                            .foregroundColor(.blue.opacity(0.7))
                            .font(.system(size: 12))
                            .padding(8)
                            .background(showMiniMap ? Color.blue.opacity(0.2) : Color.white.opacity(0.9))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Ligne de séparation style blueprint
            Rectangle()
                .fill(Color.blue.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal)
        }
        .background(Color.white.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(.blue.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Aucun Plan de Production")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.gray)
            
            Text("Calculez une production pour voir le graphe")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Graph Content
    private var graphContentView: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond blueprint amélioré
                BlueprintBackgroundView()
                
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Lignes de séparation des colonnes (niveaux) - ARRIÈRE PLAN
                        ColumnSeparatorsView(
                            layout: graphLayout,
                            zoomScale: zoomScale
                        )
                        .zIndex(-1)
                        
                        // Connexions - AVANT les noeuds mais APRÈS les séparateurs
                        GraphEdgesView(
                            links: graphLayout.links,
                            nodes: graphLayout.nodes,
                            zoomScale: zoomScale,
                            contentSize: graphLayout.contentSize
                        )
                        .frame(
                            width: graphLayout.contentSize.width * zoomScale,
                            height: graphLayout.contentSize.height * zoomScale
                        )
                        .zIndex(0) // Entre séparateurs et noeuds
                        .drawingGroup() // OPTIMISATION PERFORMANCE
                        
                        // Labels de débit sur les connexions
                        ForEach(graphLayout.links) { link in
                            if zoomScale > 0.8,
                               let fromNode = graphLayout.nodes.first(where: { $0.id == link.fromNodeID }),
                               let toNode = graphLayout.nodes.first(where: { $0.id == link.toNodeID }) {
                                LinkRateLabel(
                                    link: link,
                                    fromNode: fromNode,
                                    toNode: toNode,
                                    zoomScale: zoomScale
                                )
                            }
                        }
                        
                        // Noeuds (en premier plan)
                        ForEach(graphLayout.nodes) { node in
                            MachineNodeView(
                                node: node,
                                step: viewModel.consolidatedPlan.first(where: { $0.item.name == node.item.name }),
                                isCompact: isCompactMode,
                                isBottleneck: bottlenecks.contains { $0.item == node.item.name },
                                isOverproducing: isOverproducing(node: node),
                                zoomScale: zoomScale
                            )
                            .position(
                                x: node.position.x * zoomScale,
                                y: node.position.y * zoomScale
                            )
                            .zIndex(1) // Au premier plan
                            .onTapGesture {
                                selectedNode = node
                                HapticManager.shared.click()
                            }
                        }
                    }
                    .drawingGroup() // OPTIMISATION PERFORMANCE (RENDERING METAL)
                    .frame(
                        width: graphLayout.contentSize.width * zoomScale,
                        height: graphLayout.contentSize.height * zoomScale
                    )
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomScale = lastZoomScale * value
                        }
                        .onEnded { _ in
                            // Limiter le zoom
                            zoomScale = min(max(zoomScale, 0.3), 3.0)
                            lastZoomScale = zoomScale
                        }
                )
                
                // Overlays UI
                VStack {
                    Spacer()
                    HStack {
                        // Légende
                        LegendView()
                            .padding()
                        
                        Spacer()
                        
                        // Mini-map
                        if showMiniMap {
                            MiniMapView(
                                layout: graphLayout,
                                zoomScale: zoomScale,
                                offset: .zero,
                                onTap: { _ in }
                            )
                            .padding()
                        }
                    }
                }
                
                // Indicateur de zoom
                ZoomIndicatorView(zoomScale: zoomScale)
                    .padding()
            }
        }
    }
    
    @State private var lastZoomScale: CGFloat = 1.0
    
    // MARK: - Helpers
    private func isOverproducing(node: GraphNode) -> Bool {
        // Vérifier si le noeud produit plus que nécessaire
        guard node.type == .machine else { return false }
        
        // Vérifier que l'étape existe (sans stocker la valeur)
        guard viewModel.consolidatedPlan.contains(where: { $0.item.name == node.item.name }) else {
            return false
        }
        
        // Trouver tous les liens sortants (ce qui est produit)
        let outgoingLinks = graphLayout.links.filter { $0.fromNodeID == node.id }
        let totalOutput = outgoingLinks.reduce(0.0) { $0 + $1.rate }
        
        // Trouver tous les liens entrants vers d'autres machines (demande réelle)
        let incomingLinks = graphLayout.links.filter { link in
            link.toNodeID == node.id && 
            graphLayout.nodes.first(where: { $0.id == link.fromNodeID })?.type == .machine
        }
        let totalDemand = incomingLinks.reduce(0.0) { $0 + $1.rate }
        
        // Si la production est supérieure à la demande avec une marge, c'est de la surproduction
        // (ignorer les outputs finaux qui vont vers les goals)
        if totalDemand > 0 {
            return totalOutput > totalDemand * 1.15 // 15% de tolérance
        }
        
        // Si pas de demande mais qu'on produit, c'est peut-être un output final (normal)
        return false
    }
}

// MARK: - Vue de Noeud Machine
struct MachineNodeView: View {
    let node: GraphNode
    let step: ConsolidatedStep?
    let isCompact: Bool
    let isBottleneck: Bool
    let isOverproducing: Bool
    let zoomScale: CGFloat
    
    var body: some View {
        // Calculer toutes les valeurs en amont
        let titleColor = node.type == .output ? Color.ficsitOrange : Color.black.opacity(0.9)
        let itemColor = node.type == .output ? Color.ficsitOrange : Color.black.opacity(0.8)
        let showDetails = !isCompact && zoomScale > 0.7
        let showPower = !isCompact && zoomScale > 0.8
        let spacing = isCompact ? 4.0 : 8.0
        let padding = isCompact ? 6.0 : 10.0
        let nodeWidth = isCompact ? GraphNode.width * 0.7 : GraphNode.width
        let nodeHeight = isCompact ? GraphNode.height * 0.7 : GraphNode.height
        
        // Calculer les couleurs et styles
        let borderColor = calculateBorderColor()
        let borderWidth = calculateBorderWidth()
        let shadowColor = calculateShadowColor()
        let shadowRadius = node.type == .output ? 8.0 : 4.0
        
        return VStack(spacing: spacing) {
            // Titre - différenciation selon le type
            Text(node.label)
                .font(.system(isCompact ? .caption2 : .caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0.5)
            
            // Item name
            Text(node.item.localizedName)
                .font(.system(isCompact ? .caption2 : .caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(itemColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Badge spécial pour les produits finaux
            if node.type == .output {
                finalBadgeView
            }
            
            // Inputs/Outputs (seulement en mode détaillé ou si zoom suffisant)
            if showDetails, let step = step, let recipe = step.recipe {
                recipeDetailsView(recipe: recipe)
            }
            
            // Énergie (si visible)
            if showPower, let step = step {
                powerView(powerUsage: step.powerUsage)
            }
        }
        .padding(padding)
        .frame(width: nodeWidth, height: nodeHeight)
        .background(backgroundGradient())
        .clipShape(FicsitCardShape(cornerSize: 10))
        .overlay(borderOverlay(color: borderColor, width: borderWidth))
        .shadow(color: shadowColor.opacity(0.4), radius: shadowRadius + 2, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties & Helpers
    private var finalBadgeView: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.95), Color.green.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("FINAL")
                .font(.system(size: 7, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.green.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.25),
                    Color.green.opacity(0.15),
                    Color.green.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(5)
        .shadow(color: Color.green.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private func backgroundGradient() -> some View {
        if node.type == .output {
            LinearGradient(
                colors: [
                    Color.ficsitOrange.opacity(0.25),
                    Color.ficsitOrange.opacity(0.15),
                    Color.ficsitOrange.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if node.type == .input {
            LinearGradient(
                colors: [
                    Color.gray.opacity(0.2),
                    Color.gray.opacity(0.1),
                    Color.gray.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Gradient subtil pour les machines avec la couleur du bâtiment
            LinearGradient(
                colors: [
                    Color.white.opacity(0.95),
                    node.color.opacity(0.08),
                    Color.white.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func calculateBorderColor() -> Color {
        if node.type == .output {
            return Color.ficsitOrange
        } else if isBottleneck {
            return Color.red.opacity(0.9)
        } else if isOverproducing {
            return Color.ficsitGray.opacity(0.8)
        } else {
            // Utiliser la couleur du bâtiment avec une opacité harmonieuse
            return node.color.opacity(0.6)
        }
    }
    
    private func calculateBorderWidth() -> CGFloat {
        if node.type == .output {
            return 2.5
        } else if isBottleneck {
            return 2.5
        } else if isOverproducing {
            return 2.0
        } else {
            return 1.5
        }
    }
    
    private func calculateShadowColor() -> Color {
        if node.type == .output {
            return Color.ficsitOrange.opacity(0.3)
        } else {
            return Color.ficsitDark.opacity(0.2)
        }
    }
    
    @ViewBuilder
    private func borderOverlay(color: Color, width: CGFloat) -> some View {
        ZStack {
            // Ombre de la bordure pour effet de profondeur
            FicsitCardShape(cornerSize: 10)
                .stroke(color.opacity(0.3), lineWidth: width + 1)
            
            // Bordure principale
            FicsitCardShape(cornerSize: 10)
                .stroke(
                    LinearGradient(
                        colors: [
                            color.opacity(0.9),
                            color.opacity(0.7),
                            color.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: width
                )
        }
    }
    
    @ViewBuilder
    private func recipeDetailsView(recipe: Recipe) -> some View {
        VStack(spacing: 3) {
            // Inputs
            ForEach(Array(recipe.ingredients.keys.prefix(2)), id: \.self) { ing in
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.9), Color.blue.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("\(ing)")
                        .font(.system(size: 7, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            // Outputs
            ForEach(Array(recipe.products.keys.prefix(2)), id: \.self) { prod in
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(0.9), Color.green.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("\(prod)")
                        .font(.system(size: 7, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
    }
    
    @ViewBuilder
    private func powerView(powerUsage: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("\(Int(powerUsage)) MW")
                .font(.system(size: 7, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.black.opacity(0.7))
        }
    }
}

// MARK: - Fond Blueprint Amélioré
struct BlueprintBackgroundView: View {
    var body: some View {
        ZStack {
            // Fond papier technique avec gradient subtil
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.99),
                    Color(red: 0.94, green: 0.95, blue: 0.97),
                    Color(red: 0.96, green: 0.96, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Texture papier subtile
            GeometryReader { geometry in
                // Grille principale (plus visible)
                Path { path in
                    let step: CGFloat = 50
                    for x in stride(from: 0, to: geometry.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for y in stride(from: 0, to: geometry.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.2),
                            Color.blue.opacity(0.15),
                            Color.blue.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                
                // Grille secondaire (subtile)
                Path { path in
                    let step: CGFloat = 10
                    for x in stride(from: 0, to: geometry.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for y in stride(from: 0, to: geometry.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.blue.opacity(0.06), lineWidth: 0.4)
            }
            
            // Bordure style blueprint avec gradient
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.4),
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .ignoresSafeArea()
        }
    }
}

// MARK: - Séparateurs de Colonnes
struct ColumnSeparatorsView: View {
    let layout: GraphEngine.GraphLayout
    let zoomScale: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            // Calculer les positions des colonnes basées sur les positions réelles des noeuds
            // Les positions sont calculées comme: CGFloat(d) * columnWidth + 100
            let depths = Set(layout.nodes.map { node in
                Int((node.position.x - 100) / GraphConfig.columnWidth)
            })
            
            ForEach(Array(depths).sorted(), id: \.self) { depth in
                // Position réelle: depth * columnWidth + 100
                let xPos = (CGFloat(depth) * GraphConfig.columnWidth + 100) * zoomScale
                
                // Ligne verticale avec gradient
                Path { path in
                    path.move(to: CGPoint(x: xPos, y: 0))
                    path.addLine(to: CGPoint(x: xPos, y: geometry.size.height))
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.2),
                            Color.blue.opacity(0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [8, 6])
                )
                
                // Label de niveau avec style amélioré
                if depth > 0 {
                    Text("NIVEAU \(depth)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.blue.opacity(0.5),
                                    Color.blue.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.white.opacity(0.5), radius: 1, x: 0, y: 0.5)
                        .rotationEffect(.degrees(-90))
                        .position(
                            x: xPos - 20,
                            y: 30
                        )
                } else {
                    Text("ENTRÉES")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.blue.opacity(0.5),
                                    Color.blue.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.white.opacity(0.5), radius: 1, x: 0, y: 0.5)
                        .rotationEffect(.degrees(-90))
                        .position(
                            x: xPos - 20,
                            y: 30
                        )
                }
            }
        }
        .frame(
            width: layout.contentSize.width * zoomScale,
            height: layout.contentSize.height * zoomScale
        )
    }
}

// MARK: - Vue des Connexions (Edges) Améliorée
struct GraphEdgesView: View {
    let links: [GraphLink]
    let nodes: [GraphNode]
    let zoomScale: CGFloat
    let contentSize: CGSize
    
    var body: some View {
            Canvas { context, size in
                for link in links {
                    guard let fromNode = nodes.first(where: { $0.id == link.fromNodeID }),
                          let toNode = nodes.first(where: { $0.id == link.toNodeID }) else {
                        continue
                    }
                    
                    // Calculer les positions avec le zoom
                    let fromPos = CGPoint(
                        x: fromNode.position.x * zoomScale,
                        y: fromNode.position.y * zoomScale
                    )
                    let toPos = CGPoint(
                        x: toNode.position.x * zoomScale,
                        y: toNode.position.y * zoomScale
                    )
                    
                    // Points de connexion sur les bords des noeuds
                    let nodeWidth = GraphNode.width * zoomScale
                    let nodeHeight = GraphNode.height * zoomScale
                    
                    // Point de sortie (côté droit du noeud source, centré verticalement)
                    let start = CGPoint(
                        x: fromPos.x + nodeWidth / 2,
                        y: fromPos.y + nodeHeight / 2
                    )
                    
                    // Point d'entrée (côté gauche du noeud cible, centré verticalement)
                    let end = CGPoint(
                        x: toPos.x - nodeWidth / 2,
                        y: toPos.y + nodeHeight / 2
                    )
                    
                    // Épaisseur basée sur le débit (normalisé)
                    let maxRate = links.map { $0.rate }.max() ?? 1.0
                    let normalizedRate = link.rate / maxRate
                    let baseThickness = max(4.0, normalizedRate * 10.0 + 4.0)
                    let thickness = baseThickness * max(zoomScale, 0.5)
                    
                    // Calculer la direction
                    let dx = end.x - start.x
                    let dy = end.y - start.y
                    let distance = sqrt(dx * dx + dy * dy)
                    
                    // Courbe Bézier pour une connexion fluide
                    let curveOffset: CGFloat = distance * 0.3 // Contrôle la courbure
                    let verticalOffset: CGFloat = abs(dy) * 0.2 // Ajustement vertical pour éviter les chevauchements
                    
                    let controlPoint1 = CGPoint(
                        x: start.x + curveOffset,
                        y: start.y + verticalOffset
                    )
                    let controlPoint2 = CGPoint(
                        x: end.x - curveOffset,
                        y: end.y - verticalOffset
                    )
                    
                    var path = Path()
                    path.move(to: start)
                    path.addCurve(to: end, control1: controlPoint1, control2: controlPoint2)
                    
                    // Dessiner un contour blanc pour contraste (ombre portée)
                    context.stroke(
                        path,
                        with: .color(Color.white),
                        lineWidth: thickness + 3
                    )
                    
                    // Ligne principale avec couleur saturée
                    let strokeColor = link.color.opacity(0.95)
                    context.stroke(
                        path,
                        with: .color(strokeColor),
                        lineWidth: thickness
                    )
                    
                    // Ligne de brillance subtile au-dessus pour effet 3D
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(0.4)),
                        lineWidth: max(1.0, thickness * 0.25)
                    )
                    
                    // Flèche à la fin
                    let angle = atan2(dy, dx)
                    let arrowLength: CGFloat = 18 * max(zoomScale, 0.5)
                    let arrowWidth: CGFloat = 10 * max(zoomScale, 0.5)
                    
                    let arrowPoint1 = CGPoint(
                        x: end.x - arrowLength * cos(angle) + arrowWidth * sin(angle),
                        y: end.y - arrowLength * sin(angle) - arrowWidth * cos(angle)
                    )
                    let arrowPoint2 = CGPoint(
                        x: end.x - arrowLength * cos(angle) - arrowWidth * sin(angle),
                        y: end.y - arrowLength * sin(angle) + arrowWidth * cos(angle)
                    )
                    
                    var arrowPath = Path()
                    arrowPath.move(to: end)
                    arrowPath.addLine(to: arrowPoint1)
                    arrowPath.addLine(to: arrowPoint2)
                    arrowPath.closeSubpath()
                    
                    // Contour blanc pour la flèche (ombre)
                    context.fill(arrowPath, with: .color(Color.white))
                    
                    // Flèche principale avec couleur saturée
                    context.fill(arrowPath, with: .color(strokeColor))
                    
                    // Reflet brillant sur la flèche pour effet 3D
                    context.fill(arrowPath, with: .color(Color.white.opacity(0.25)))
                }
            }
            .frame(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale)
        }
    }

// MARK: - Légende
struct LegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LÉGENDE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.ficsitGray)
            
            HStack(spacing: 12) {
                LegendItem(color: .ficsitGray, label: "Entrée")
                LegendItem(color: Color(red: 0.8, green: 0.3, blue: 0.3), label: "Fonderie")
                LegendItem(color: .ficsitOrange, label: "Constructeur")
                LegendItem(color: Color(red: 0.3, green: 0.6, blue: 0.8), label: "Assembleuse")
                LegendItem(color: .ficsitOrange, label: "Sortie")
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.ficsitOrange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.black.opacity(0.7))
        }
    }
}

// MARK: - Indicateur de Zoom
struct ZoomIndicatorView: View {
    let zoomScale: CGFloat
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
            Text("\(Int(zoomScale * 100))%")
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundColor(.blue.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.9))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Label de Débit sur les Connexions
struct LinkRateLabel: View {
    let link: GraphLink
    let fromNode: GraphNode
    let toNode: GraphNode
    let zoomScale: CGFloat
    
    var body: some View {
        let fromPos = CGPoint(
            x: fromNode.position.x * zoomScale,
            y: fromNode.position.y * zoomScale
        )
        let toPos = CGPoint(
            x: toNode.position.x * zoomScale,
            y: toNode.position.y * zoomScale
        )
        
        let midPoint = CGPoint(
            x: (fromPos.x + toPos.x) / 2,
            y: (fromPos.y + toPos.y) / 2 - 20
        )
        
        Text("\(String(format: "%.1f", link.rate))/m")
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundColor(.black.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        link.color.opacity(0.1),
                        Color.white.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        LinearGradient(
                            colors: [
                                link.color.opacity(0.6),
                                link.color.opacity(0.4),
                                link.color.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            .position(midPoint)
    }
}

// MARK: - Mini Map
struct MiniMapView: View {
    let layout: GraphEngine.GraphLayout
    let zoomScale: CGFloat
    let offset: CGSize
    let onTap: (CGPoint) -> Void
    
    var body: some View {
        ZStack {
            // Fond
            Color.black.opacity(0.7)
                .cornerRadius(8)
            
            // Représentation simplifiée
            GeometryReader { geometry in
                let scale = min(
                    geometry.size.width / layout.contentSize.width,
                    geometry.size.height / layout.contentSize.height
                )
                
                ZStack {
                    // Connexions
                    ForEach(layout.links) { link in
                        if let fromNode = layout.nodes.first(where: { $0.id == link.fromNodeID }),
                           let toNode = layout.nodes.first(where: { $0.id == link.toNodeID }) {
                            Path { path in
                                path.move(to: CGPoint(
                                    x: fromNode.position.x * scale,
                                    y: fromNode.position.y * scale
                                ))
                                path.addLine(to: CGPoint(
                                    x: toNode.position.x * scale,
                                    y: toNode.position.y * scale
                                ))
                            }
                            .stroke(link.color.opacity(0.3), lineWidth: 0.5)
                        }
                    }
                    
                    // Noeuds
                    ForEach(layout.nodes) { node in
                        Circle()
                            .fill(node.color)
                            .frame(width: 4, height: 4)
                            .position(
                                x: node.position.x * scale,
                                y: node.position.y * scale
                            )
                    }
                }
            }
            .padding(4)
        }
        .frame(width: 150, height: 150)
        .onTapGesture { location in
            // Convertir le tap en position dans le graphique
            let scale = min(
                150.0 / layout.contentSize.width,
                150.0 / layout.contentSize.height
            )
            let graphPoint = CGPoint(
                x: location.x / scale,
                y: location.y / scale
            )
            onTap(graphPoint)
        }
    }
}

// MARK: - Sheet de Détails Machine
struct MachineDetailSheet: View {
    let node: GraphNode
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingBlueprint = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(node.item.name)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(node.label)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        .padding()
                        
                        // Blueprint Button
                        if node.type == .machine, getStep() != nil {
                            Button(action: { showingBlueprint = true }) {
                                HStack {
                                    Image(systemName: "square.dashed")
                                    Text("VOIR BLUEPRINT")
                                }
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }

                        // Recette
                        if let recipe = getRecipe() {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("RECETTE")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.ficsitOrange)
                                
                                Text(recipe.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Divider()
                                
                                // Ingrédients
                                Text("ENTRÉES")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.blue)
                                
                                ForEach(Array(recipe.ingredients.keys), id: \.self) { ing in
                                    HStack {
                                        Text(ing)
                                        Spacer()
                                        Text("\(String(format: "%.2f", recipe.ingredients[ing] ?? 0))/min")
                                            .foregroundColor(.ficsitOrange)
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                }
                                
                                Divider()
                                
                                // Produits
                                Text("SORTIES")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.green)
                                
                                ForEach(Array(recipe.products.keys), id: \.self) { prod in
                                    HStack {
                                        Text(prod)
                                        Spacer()
                                        Text("\(String(format: "%.2f", recipe.products[prod] ?? 0))/min")
                                            .foregroundColor(.ficsitOrange)
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                }
                                
                                Divider()
                                
                                // Énergie
                                HStack {
                                    Text("CONSOMMATION")
                                    Spacer()
                                    Text("\(Int(recipe.machine.powerConsumption)) MW")
                                        .foregroundColor(.yellow)
                                }
                                .font(.system(.caption, design: .monospaced))
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Détails Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.ficsitOrange)
                }
            }
            .fullScreenCover(isPresented: $showingBlueprint) {
                if let step = getStep() {
                    FactoryLayoutView(plan: ConstructionEngine().generateManifold(for: step, db: db))
                }
            }
        }
    }
    
    private func getRecipe() -> Recipe? {
        db.getRecipesOptimized(producing: node.item.name).first
    }

    private func getStep() -> ConsolidatedStep? {
        viewModel.consolidatedPlan.first(where: { $0.item.name == node.item.name })
    }
}

// MARK: - Sheet de Détails Lien
struct LinkDetailSheet: View {
    let link: GraphLink
    let layout: GraphEngine.GraphLayout
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("DÉTAILS CONNEXION")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.ficsitOrange)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Item:")
                            Spacer()
                            Text(link.itemName)
                                .foregroundColor(.ficsitOrange)
                        }
                        
                        HStack {
                            Text("Taux:")
                            Spacer()
                            Text("\(String(format: "%.2f", link.rate))/min")
                                .foregroundColor(.ficsitOrange)
                        }
                        
                        if let fromNode = layout.nodes.first(where: { $0.id == link.fromNodeID }),
                           let toNode = layout.nodes.first(where: { $0.id == link.toNodeID }) {
                            Divider()
                            
                            Text("De: \(fromNode.item.name)")
                                .font(.system(.caption, design: .monospaced))
                            
                            Text("Vers: \(toNode.item.name)")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Détails Lien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.ficsitOrange)
                }
            }
        }
    }
}

