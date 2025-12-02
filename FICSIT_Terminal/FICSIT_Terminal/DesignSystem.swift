import SwiftUI

// 1. FORME : COINS COUPÉS (CHAMFERED) - Signature FICSIT
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

// 2. MODIFIER : STYLE DE CARTE TECHNIQUE
struct FicsitCardStyle: ViewModifier {
    var borderColor: Color = .ficsitOrange.opacity(0.3)
    var fill: Color = Color(red: 0.1, green: 0.1, blue: 0.12)
    
    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(FicsitCardShape(cornerSize: 8))
            .overlay(
                FicsitCardShape(cornerSize: 8)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func ficsitCard(borderColor: Color = .ficsitOrange.opacity(0.3), fill: Color = Color(red: 0.12, green: 0.12, blue: 0.14)) -> some View {
        self.modifier(FicsitCardStyle(borderColor: borderColor, fill: fill))
    }
}

// 3. BOUTON FICSIT
struct FicsitButtonStyle: ButtonStyle {
    var primary: Bool = true
    var color: Color = .ficsitOrange
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .monospaced))
            .fontWeight(.bold)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                FicsitCardShape(cornerSize: 6)
                    .fill(primary ? color : Color.white.opacity(0.05))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(FicsitCardShape(cornerSize: 6).stroke(primary ? .white.opacity(0.3) : color, lineWidth: 1))
            .foregroundColor(primary ? .black : color)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// 4. HEADER TECHNIQUE
struct FicsitHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.ficsitOrange)
                .padding(6)
                .background(Color.ficsitOrange.opacity(0.15))
                .clipShape(Circle())
            
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1.5)
            
            VStack { Divider().background(Color.ficsitOrange.opacity(0.3)) }
        }
        .padding(.vertical, 8)
    }
}

// 5. STEPPER CUSTOM (Plus/Moins)
struct FicsitStepper: View {
    @Binding var value: Double
    let step: Double = 0.5
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: { if value > step { value -= step } }) {
                Image(systemName: "minus")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            
            Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 20)
            
            Text(String(format: "%.1f", value))
                .font(.system(.body, design: .monospaced))
                .frame(width: 50)
                .foregroundColor(.white)
            
            Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 20)
            
            Button(action: { value += step }) {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.5), lineWidth: 1))
        .foregroundColor(.ficsitOrange)
    }
}

// 6. FOND D'ÉCRAN "BLUEPRINT"
struct FicsitBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea() // Plus sombre
            
            // Grille subtile
            GeometryReader { geometry in
                Path { path in
                    let step: CGFloat = 40
                    for x in stride(from: 0, to: geometry.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for y in stride(from: 0, to: geometry.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
            }
        }
    }
}
