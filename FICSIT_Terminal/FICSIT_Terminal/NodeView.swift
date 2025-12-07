import SwiftUI

struct NodeView: View {
    let node: GraphNode

    var body: some View {
        ZStack {
            // Fond technique (Blueprint style)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(node.color, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 2)

            VStack(spacing: 2) {
                // En-tête avec Label (ex: "4.5x Constructor")
                HStack {
                    Circle()
                        .fill(node.color)
                        .frame(width: 8, height: 8)
                    Text(node.label)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(node.color)
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)

                Divider().background(node.color.opacity(0.3))

                Spacer()

                // Icone ou Nom de l'item principal
                Text(node.subLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Nom de la recette (si machine)
                if let recipe = node.recipeName {
                    Text(recipe)
                        .font(.system(size: 10, weight: .light, design: .italic))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .padding(.bottom, 4)
                }

                Spacer()

                // Indicateurs de ports (visuels)
                HStack {
                    // Input ports visual hint
                    if node.type != .input {
                        Circle().fill(Color.gray).frame(width: 4, height: 4)
                    }
                    Spacer()
                    // Output ports visual hint
                    if node.type != .output {
                        Circle().fill(Color.gray).frame(width: 4, height: 4)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
        .frame(width: GraphNode.width, height: GraphNode.height)
    }
}
