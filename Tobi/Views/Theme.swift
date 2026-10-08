import SwiftUI

/// Cores do Tobi: fundo quente de papel, macros com cor própria.
enum Theme {
    static let backgroundTop = Color(light: .init(red: 0.99, green: 0.97, blue: 0.95),
                                     dark: .init(red: 0.09, green: 0.08, blue: 0.08))
    static let backgroundBottom = Color(light: .init(red: 0.95, green: 0.94, blue: 0.97),
                                        dark: .init(red: 0.07, green: 0.07, blue: 0.10))

    static let carbs = Color(red: 0.90, green: 0.26, blue: 0.33)
    static let protein = Color(red: 0.93, green: 0.70, blue: 0.13)
    static let fat = Color(red: 0.62, green: 0.32, blue: 0.86)
    static let sugar = Color(red: 0.95, green: 0.42, blue: 0.67)
    static let fiber = Color(red: 0.30, green: 0.72, blue: 0.40)
    static let sodium = Color(red: 0.25, green: 0.55, blue: 0.95)

    static var background: some View {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

extension View {
    /// A superfície das metas do onboarding, compartilhada pelas telas do app.
    func tobiGlassSurface(alignment: Alignment = .leading) -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: alignment)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

/// Reforço do desfoque nativo das bordas: um véu da cor do fundo que vai de cheio a transparente,
/// pra o texto que passa por baixo das barras sumir de vez em vez de só embaçar.
struct EdgeFade: View {
    let edge: VerticalEdge

    var body: some View {
        let color = edge == .top ? Theme.backgroundTop : Theme.backgroundBottom
        LinearGradient(
            stops: [.init(color: color.opacity(0.9), location: 0),
                    .init(color: color.opacity(0.6), location: 0.5),
                    .init(color: color.opacity(0), location: 1)],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
    }
}
