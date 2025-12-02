import SwiftUI

struct FlowChartView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    private let engine = GraphEngine()
    @State private var layout: GraphEngine.GraphLayout?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea() // Fond très sombre (Blueprint)
                
                if viewModel.consolidatedPlan.isEmpty {
                    // (Empty state inchangé)
                    VStack { Text("BLUEPRINT EMPTY").foregroundColor(.gray) }
                } else {
                    GeometryReader { geo in
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            ZStack(alignment: .topLeading) {
                                
                                // GRID
                                BlueprintGrid()
                                
                                if let layout = layout {
                                    // LIGNES ORTHOGONALES
                                    ForEach(layout.links) { link in
                                        drawOrthogonalLink(link, nodes: layout.nodes)
                                    }
                                    
                                    // LABELS
                                    ForEach(layout.links) { link in
                                        drawLinkBadge(link, nodes: layout.nodes, userLimit: viewModel.selectedBeltLevel.speed)
                                    }
                                    
                                    // NOEUDS
                                    ForEach(layout.nodes) { node in
                                        NodeView(node: node).position(node.position)
                                    }
                                }
                            }
                            .frame(width: (layout?.contentSize.width ?? 1000) + 200, height: (layout?.contentSize.height ?? 1000) + 200)
                            .scaleEffect(scale)
                            .gesture(MagnificationGesture().onChanged{v in scale=lastScale*v}.onEnded{v in lastScale=scale})
                        }
                    }
                }
            }
            .navigationBarTitle("Blueprint CAD", displayMode: .inline)
            .onAppear { generateGraph() }
            .onChange(of: viewModel.consolidatedPlan.count) { generateGraph() }
        }
    }
    
    func generateGraph() {
        let db = FICSITDatabase.shared
        withAnimation(.spring()) { self.layout = engine.generateLayout(from: viewModel.consolidatedPlan, inputs: viewModel.userInputs, goals: viewModel.goals, sinkResult: viewModel.sinkResult, db: db) }
    }
    
    // DESSIN ORTHOGONAL (Circuit Imprimé)
    func drawOrthogonalLink(_ link: GraphLink, nodes: [GraphNode]) -> some View {
        let start = nodes.first(where: { $0.id == link.fromNodeID })?.position ?? .zero
        let end = nodes.first(where: { $0.id == link.toNodeID })?.position ?? .zero
        
        let p1 = CGPoint(x: start.x + GraphNode.width/2, y: start.y) // Sortie Droite
        let p4 = CGPoint(x: end.x - GraphNode.width/2, y: end.y)     // Entrée Gauche
        
        // Points intermédiaires pour faire des angles droits
        let midX = (p1.x + p4.x) / 2
        let p2 = CGPoint(x: midX, y: p1.y)
        let p3 = CGPoint(x: midX, y: p4.y)
        
        return Path { path in
            path.move(to: p1)
            path.addLine(to: p2) // Horizontal
            path.addLine(to: p3) // Vertical
            path.addLine(to: p4) // Horizontal
        }
        .stroke(link.color.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
    }
    
    func drawLinkBadge(_ link: GraphLink, nodes: [GraphNode], userLimit: Double) -> some View {
        // Position au milieu du segment vertical
        let start = nodes.first(where: { $0.id == link.fromNodeID })?.position ?? .zero
        let end = nodes.first(where: { $0.id == link.toNodeID })?.position ?? .zero
        let midX = (start.x + GraphNode.width/2 + end.x - GraphNode.width/2) / 2
        let midY = (start.y + end.y) / 2
        
        let belt = getMultiBeltInfo(rate: link.rate, limit: userLimit)
        
        return Text("\(belt.label)\n\(Int(link.rate))/m")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .multilineTextAlignment(.center)
            .foregroundColor(belt.color)
            .padding(3)
            .background(Color.black.opacity(0.8))
            .border(belt.color, width: 1)
            .position(x: midX, y: midY)
    }
    
    // Helpers Belt (Inchangés, copier depuis version précédente ou Models)
    func getMultiBeltInfo(rate: Double, limit: Double) -> (label: String, color: Color) {
         // ... (Copier la logique Mk1-Mk5 ici) ...
         if rate <= 60 { return ("Mk1", .gray) }
         return ("Mk?", .ficsitOrange) // Fallback simple
    }
}

// Fond Quadrillé Technique
struct BlueprintGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let step: CGFloat = 20 // Grille fine
                // Lignes fines
                for x in stride(from: 0, to: geometry.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for y in stride(from: 0, to: geometry.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }.stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            
            Path { path in
                let step: CGFloat = 100 // Grille majeure
                for x in stride(from: 0, to: geometry.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for y in stride(from: 0, to: geometry.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }.stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}
