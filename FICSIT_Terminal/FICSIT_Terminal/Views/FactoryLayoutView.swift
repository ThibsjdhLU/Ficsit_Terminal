import SwiftUI

struct FactoryLayoutView: View {
    let plan: ConstructionPlan
    @Environment(\.presentationMode) var presentationMode

    // Zoom & Pan state
    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Constants
    private let foundationSize: CGFloat = 64 // 8m = 64px screen (scale 1m = 8px)
    private let metersToPoints: CGFloat = 8.0

    var body: some View {
        ZStack {
            // Background grid
            Color.ficsitDark.ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    // Infinite Grid Layer
                    GridBackground(spacing: foundationSize)
                        .opacity(0.1)

                    // Content Layer
                    Canvas { context, size in
                        // Transform context for zoom/pan
                        context.translateBy(x: size.width/2 + offset.width, y: size.height/2 + offset.height)
                        context.scaleBy(x: zoom, y: zoom)

                        // Centering the layout
                        let contentWidth = plan.width * metersToPoints
                        let contentHeight = plan.length * metersToPoints
                        context.translateBy(x: -contentWidth/2, y: -contentHeight/2)

                        // Draw Items
                        for item in plan.items {
                            drawItem(item, context: context)
                        }

                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { value in
                                lastOffset = offset
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoom = max(0.2, min(5.0, value))
                            }
                    )
                }
            }

            // Overlay UI
            VStack {
                HStack {
                    Text("\(Localization.translate("BLUEPRINT")) : \(plan.name)")
                        .font(.system(.headline, design: .monospaced))
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.ficsitOrange)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.ficsitOrange, lineWidth: 1))

                    Spacer()

                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.ficsitGray)
                    }
                }
                .padding()

                Spacer()

                // Legend
                HStack(spacing: 15) {
                    LegendLabel(color: .ficsitOrange, text: Localization.translate("Machine"))
                    LegendLabel(color: .ficsitGray, text: Localization.translate("Splitter/Merger"))
                    LegendLabel(color: .green, text: Localization.translate("Input"))
                    LegendLabel(color: .ficsitOrange.opacity(0.5), text: Localization.translate("Output"))
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ficsitOrange.opacity(0.5), lineWidth: 1))
                .padding(.bottom)
            }
        }
    }

    private func drawItem(_ item: ConstructionItem, context: GraphicsContext) {
        let x = item.position.x * metersToPoints
        let y = item.position.y * metersToPoints

        switch item.type {
        case .machine:
            if let dims = item.dimensions {
                let w = dims.width * metersToPoints
                let l = dims.length * metersToPoints
                let rect = CGRect(x: x, y: y, width: w, height: l)

                // Body
                context.fill(Path(rect), with: .color(Color.ficsitOrange.opacity(0.8)))
                context.stroke(Path(rect), with: .color(.white), lineWidth: 2)

                // Name
                context.draw(
                    Text(Localization.translate(item.name)).font(.system(size: 10, weight: .bold)).foregroundColor(.black),
                    at: CGPoint(x: x + w/2, y: y + l/2)
                )

                // Direction Arrow
                let arrowPath = Path { p in
                    p.move(to: CGPoint(x: x + w/2, y: y + l*0.2))
                    p.addLine(to: CGPoint(x: x + w/2, y: y + l*0.8))
                    p.addLine(to: CGPoint(x: x + w*0.4, y: y + l*0.7))
                    p.move(to: CGPoint(x: x + w/2, y: y + l*0.8))
                    p.addLine(to: CGPoint(x: x + w*0.6, y: y + l*0.7))
                }
                context.stroke(arrowPath, with: .color(.black.opacity(0.5)), lineWidth: 2)
            }

        case .splitter:
            let size = 2.0 * metersToPoints
            let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
            context.fill(Path(rect), with: .color(.ficsitGray))
            context.stroke(Path(rect), with: .color(.white), lineWidth: 1)
            context.draw(Text("S").font(.caption).foregroundColor(.white), at: CGPoint(x: x, y: y))

        case .merger:
            let size = 2.0 * metersToPoints
            let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
            context.fill(Path(rect), with: .color(.ficsitGray))
            context.stroke(Path(rect), with: .color(.white), lineWidth: 1)
            context.draw(Text("M").font(.caption).foregroundColor(.white), at: CGPoint(x: x, y: y))

        case .belt:
            if let path = item.path, path.count >= 2 {
                // Dessiner le chemin complet
                var pathObj = Path()
                let start = CGPoint(x: path[0].x * metersToPoints, y: path[0].y * metersToPoints)
                pathObj.move(to: start)

                for i in 1..<path.count {
                    let point = CGPoint(x: path[i].x * metersToPoints, y: path[i].y * metersToPoints)
                    pathObj.addLine(to: point)
                }

                // Dessiner le convoyeur
                context.stroke(pathObj, with: .color(Color.ficsitOrange.opacity(0.6)), lineWidth: 3)

                // Dessiner les flèches de direction (tous les X points)
                // (Simplifié pour V1: juste la ligne)

            } else {
                // Fallback si pas de chemin
                let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                context.fill(Path(rect), with: .color(.ficsitOrange))
            }

        default:
            break
        }
    }
}

struct GridBackground: View {
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            let path = Path { p in
                for x in stride(from: 0, to: size.width, by: spacing) {
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, to: size.height, by: spacing) {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            context.stroke(path, with: .color(Color.white.opacity(0.1)), lineWidth: 1)
        }
    }
}

struct LegendLabel: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption).foregroundColor(.white)
        }
    }
}
