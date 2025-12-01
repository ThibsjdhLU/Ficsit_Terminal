import SwiftUI

// 1. FORME : COINS COUPÉS
struct FicsitCardShape: Shape {
    let cornerSize: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cornerSize, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerSize, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerSize))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerSize))
        path.addLine(to: CGPoint(x: rect.maxX - cornerSize, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerSize, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerSize))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerSize))
        path.closeSubpath()
        return path
    }
}

// 2. MODIFIER : STYLE DE CARTE STANDARD
struct FicsitCardStyle: ViewModifier {
    var borderColor: Color = .white.opacity(0.1)
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(red: 0.1, green: 0.1, blue: 0.12)) // Gris très foncé
            .clipShape(FicsitCardShape(cornerSize: 10))
            .overlay(FicsitCardShape(cornerSize: 10).stroke(borderColor, lineWidth: 1))
    }
}

extension View {
    func ficsitCard(borderColor: Color = .white.opacity(0.1)) -> some View {
        self.modifier(FicsitCardStyle(borderColor: borderColor))
    }
}

// 3. STYLE DE BOUTON
struct FicsitButtonStyle: ButtonStyle {
    var primary: Bool = true
    var color: Color = .ficsitOrange
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .monospaced))
            .fontWeight(.bold)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                FicsitCardShape(cornerSize: 8)
                    .fill(primary ? color : Color.white.opacity(0.05))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(FicsitCardShape(cornerSize: 8).stroke(primary ? .white.opacity(0.2) : color, lineWidth: 1))
            .foregroundColor(primary ? .black : color)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 4. HEADER DE SECTION
struct FicsitHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.ficsitOrange)
            Text(title.uppercased())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.black)
                .foregroundColor(.ficsitOrange)
                .tracking(1)
            Spacer()
            Rectangle().fill(Color.ficsitOrange.opacity(0.5)).frame(height: 1)
        }
        .padding(.vertical, 10)
    }
}

// 5. CHAMP TEXTE TECHNIQUE
struct FicsitTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.ficsitOrange.opacity(0.5), lineWidth: 1)
            )
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
    }
}

// 6. FOND D'ÉCRAN
struct FicsitBackground: View {
    var body: some View {
        ZStack {
            Color.ficsitDark.ignoresSafeArea()
            GeometryReader { geometry in
                Path { path in
                    let step: CGFloat = 40
                    for y in stride(from: 0, to: geometry.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.02), lineWidth: 1)
            }
        }
    }
}
