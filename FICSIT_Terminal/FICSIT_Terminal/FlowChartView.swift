import SwiftUI

struct FlowChartView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    private let engine = GraphEngine()
    @State private var layout: GraphEngine.GraphLayout?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                
                if viewModel.consolidatedPlan.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.system(size: 60))
                            .foregroundColor(.ficsitGray)
                        Text("BLUEPRINT EMPTY")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Configure a production plan first.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            
                            // 1. LIENS (Derrière)
                            if let layout = layout {
                                ForEach(layout.links) { link in
                                    drawLinkLine(link, nodes: layout.nodes)
                                }
                            }
                            
                            // 2. ÉTIQUETTES (Au milieu)
                            if let layout = layout {
                                ForEach(layout.links) { link in
                                    drawSmartBeltLabel(
                                        link,
                                        nodes: layout.nodes,
                                        userLimit: viewModel.selectedBeltLevel.speed
                                    )
                                }
                            }
                            
                            // 3. NOEUDS (Devant)
                            if let layout = layout {
                                ForEach(layout.nodes) { node in
                                    NodeView(node: node)
                                        .position(node.position)
                                }
                            }
                        }
                        .frame(width: layout?.contentSize.width ?? 500, height: layout?.contentSize.height ?? 500)
                        .background(
                            ZStack {
                                Color(red: 0.12, green: 0.12, blue: 0.14)
                                GridPattern()
                            }
                        )
                    }
                }
            }
            .navigationBarTitle("Blueprint Viz", displayMode: .inline)
            .onAppear { generateGraph() }
            .onChange(of: viewModel.consolidatedPlan.count) { generateGraph() }
        }
    }
    
    func generateGraph() {
        let db = FICSITDatabase.shared
        withAnimation(.spring()) {
            self.layout = engine.generateLayout(
                from: viewModel.consolidatedPlan,
                inputs: viewModel.userInputs,
                db: db
            )
        }
    }
    
    // --- DESSIN DES LIGNES ---
    // AMÉLIORATION : Courbe de Bézier plus "Technique"
    func drawLinkLine(_ link: GraphLink, nodes: [GraphNode]) -> some View {
        let start = nodes.first(where: { $0.id == link.fromNodeID })?.position ?? .zero
        let end = nodes.first(where: { $0.id == link.toNodeID })?.position ?? .zero
        
        let startPoint = CGPoint(x: start.x + GraphNode.width/2, y: start.y)
        let endPoint = CGPoint(x: end.x - GraphNode.width/2, y: end.y)
        
        return Path { path in
            path.move(to: startPoint)
            
            // Calcul d'une courbe sigmoïde tendue
            // Le point de contrôle est à mi-chemin horizontalement, mais reste au niveau Y de départ/arrivée
            let midX = (startPoint.x + endPoint.x) / 2
            let control1 = CGPoint(x: midX, y: startPoint.y)
            let control2 = CGPoint(x: midX, y: endPoint.y)
            
            path.addCurve(to: endPoint, control1: control1, control2: control2)
        }
        .stroke(link.color.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
    
    func drawSmartBeltLabel(_ link: GraphLink, nodes: [GraphNode], userLimit: Double) -> some View {
        let start = nodes.first(where: { $0.id == link.fromNodeID })?.position ?? .zero
        let end = nodes.first(where: { $0.id == link.toNodeID })?.position ?? .zero
        
        // Position au milieu géométrique de la courbe
        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2
        
        let beltInfo = getMultiBeltInfo(rate: link.rate, limit: userLimit)
        
        return VStack(spacing: 2) {
            Text(beltInfo.label)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .background(beltInfo.color)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1))
            
            Text("\(Int(link.rate))/m")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.6)))
        }
        .position(x: midX, y: midY)
        .shadow(radius: 3)
    }
    
    func getMultiBeltInfo(rate: Double, limit: Double) -> (label: String, color: Color) {
        if rate <= limit {
            if rate <= 60 { return ("Mk1", Color.gray) }
            if rate <= 120 { return ("Mk2", Color.orange) }
            if rate <= 270 { return ("Mk3", Color(red: 0.2, green: 0.6, blue: 1.0)) }
            if rate <= 480 { return ("Mk4", Color(red: 0.6, green: 0.4, blue: 0.3)) }
            return ("Mk5", Color(red: 1.0, green: 0.4, blue: 0.6))
        }
        let numberOfBelts = Int(ceil(rate / limit))
        let beltName = getBeltName(limit: limit)
        return ("\(numberOfBelts)x \(beltName)", Color.purple)
    }
    
    func getBeltName(limit: Double) -> String {
        switch Int(limit) {
        case 60: return "Mk1"
        case 120: return "Mk2"
        case 270: return "Mk3"
        case 480: return "Mk4"
        case 780: return "Mk5"
        default: return "Belt"
        }
    }
}

// NodeView et GridPattern restent inchangés
struct NodeView: View {
    let node: GraphNode
    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ItemIcon(item: node.item, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.label).font(.system(size: 11, weight: .bold)).foregroundColor(.white).lineLimit(1)
                    Text(node.subLabel).font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundColor(.ficsitOrange)
                    if let recipe = node.recipeName { Text(recipe).font(.system(size: 9)).foregroundColor(.gray).lineLimit(1) }
                }
                Spacer()
            }
            .padding(8).frame(width: GraphNode.width, height: GraphNode.height).background(LinearGradient(gradient: Gradient(colors: [node.color.opacity(0.8), node.color.opacity(0.4)]), startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.4), lineWidth: 1)).shadow(color: node.color.opacity(0.3), radius: 10, x: 0, y: 5)
            Circle().fill(Color.white).frame(width: 6, height: 6).offset(x: -GraphNode.width/2)
            Circle().fill(Color.white).frame(width: 6, height: 6).offset(x: GraphNode.width/2)
        }
    }
}

struct GridPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let step: CGFloat = 50
                for x in stride(from: 0, to: geometry.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for y in stride(from: 0, to: geometry.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }.stroke(Color.white.opacity(0.03), lineWidth: 1)
        }
    }
}
