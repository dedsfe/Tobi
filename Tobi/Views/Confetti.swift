import SwiftUI

/// Chuva curta de confete nas cores dos macros. Cai uma vez só e some; com Reduzir Movimento, não aparece.
struct Confetti: View {
    var count = 28
    @State private var falling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors = [Theme.protein, Theme.carbs, Theme.fat, Theme.sugar, Theme.fiber, Theme.sodium]

    /// Cada peça tem posição, atraso, giro e cor fixos (sorteados uma vez), pra o redesenho não embaralhar.
    private let pieces: [Piece]

    init(count: Int = 28) {
        self.count = count
        pieces = (0..<count).map { index in
            Piece(x: .random(in: 0.04...0.96), delay: .random(in: 0...0.35), spin: .random(in: -540...540),
                  drift: .random(in: -40...40), width: .random(in: 6...10), height: .random(in: 10...16),
                  color: Self.colors[index % Self.colors.count], duration: .random(in: 1.6...2.4))
        }
    }

    var body: some View {
        GeometryReader { proxy in
            if !reduceMotion {
                ForEach(pieces.indices, id: \.self) { index in
                    let piece = pieces[index]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(falling ? piece.spin : 0))
                        .position(x: proxy.size.width * piece.x + (falling ? piece.drift : 0),
                                  y: falling ? proxy.size.height + 30 : -20)
                        .opacity(falling ? 0 : 1)
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: falling)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { falling = true }
    }

    private struct Piece {
        let x: CGFloat
        let delay: Double
        let spin: Double
        let drift: CGFloat
        let width: CGFloat
        let height: CGFloat
        let color: Color
        let duration: Double
    }
}
