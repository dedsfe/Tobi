import SwiftUI

/// Estampa de comidinhas em traço lilás, a mesma das imagens da loja. Fica atrás do Tobi,
/// desliza devagar na diagonal e some pra baixo antes do texto, pra não atrapalhar a leitura.
struct FoodPattern: View {
    /// Lado do ladrilho em pontos: cada desenho fica com uns 20 pt.
    private static let tile: CGFloat = 300
    /// Pontos por segundo: dá pra perceber que vive, sem chamar atenção.
    private static let drift = 7.0
    private static let image = UIImage(named: "food-pattern.png")?.cgImage
        .map { UIImage(cgImage: $0, scale: CGFloat($0.width) / tile, orientation: .up) }
    private static let ink = Color(light: Color(red: 0.55, green: 0.43, blue: 0.84).opacity(0.42),
                                   dark: Color(red: 0.72, green: 0.62, blue: 0.98).opacity(0.24))

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let image = Self.image {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                let shift = reduceMotion ? 0 : CGFloat((timeline.date.timeIntervalSinceReferenceDate * Self.drift)
                    .truncatingRemainder(dividingBy: Self.tile))
                GeometryReader { proxy in
                    Image(uiImage: image)
                        .renderingMode(.template)
                        .resizable(resizingMode: .tile)
                        .foregroundStyle(Self.ink)
                        .frame(width: proxy.size.width + Self.tile, height: proxy.size.height + Self.tile)
                        .offset(x: -shift, y: -shift)
                }
                .clipped()
            }
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: 0.4),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
