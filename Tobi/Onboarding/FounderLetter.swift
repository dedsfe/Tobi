import SwiftUI

/// "Por que o Tobi custa isso?": o André explica o preço, do jeito que ele falaria.
/// Abre do paywall. A foto do André é a capa e vira papel por baixo do título; a carta
/// termina com a assinatura escrita na hora. Sem `founder.jpg`, o rostinho do Tobi na capa.
struct FounderLetter: View {
    @Environment(\.dismiss) private var dismiss
    @State private var visible = false
    @State private var photoSettled = false
    @State private var signed = false
    @State private var letterHeight: CGFloat = 0

    private static let photo = UIImage(named: "founder.jpg")
    private static let minPhoto: CGFloat = 240
    /// Quanto o título sobe por cima do fim da foto, onde ela já virou papel.
    private static let overlap: CGFloat = 64

    var body: some View {
        GeometryReader { proxy in
            // A foto fica com todo o espaço que a carta não usa: cabe numa tela só.
            let room = proxy.size.height + proxy.safeAreaInsets.top
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    cover
                        .frame(height: max(Self.minPhoto, room - letterHeight + Self.overlap))
                    letter
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { letterHeight = $0 }
                        .padding(.top, -Self.overlap)
                }
            }
            .ignoresSafeArea(edges: .top)
            .scrollBounceBehavior(.basedOnSize)
        }
        .overlay(alignment: .topTrailing) {
            Button("Fechar", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 30, height: 30)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .foregroundStyle(.primary)
                .padding(16)
        }
        .background { Theme.background }
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: signed)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8)) { photoSettled = true }
            withAnimation(Motion.surface) { visible = true }
            withAnimation(.easeInOut(duration: 1.1).delay(0.75)) { signed = true }
        }
    }

    /// A foto entra um pouco mais perto e assenta devagar, e o pé dela some no fundo da carta.
    private var cover: some View {
        Color.clear
            .overlay {
                if let photo = Self.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(photoSettled ? 1 : 1.12, anchor: UnitPoint(x: 0.36, y: 0.42))
                } else {
                    Image("tobi-head")
                        .resizable()
                        .scaledToFit()
                        .padding(70)
                        .padding(.bottom, Self.overlap)
                }
            }
            .clipped()
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0.5),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topLeading) {
                if Self.photo != nil {
                    Label("Zermatt, Suíça", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.leading, 16)
                        .padding(.top, 20)
                        .reveal(visible, order: 3)
                }
            }
            .opacity(visible ? 1 : 0)
    }

    private var letter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Oi, eu sou o André 👋")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .reveal(visible, order: 1)

            VStack(alignment: .leading, spacing: 14) {
                Text("Eu fiz o Tobi e queria te contar, sem enrolação, por que ele custa isso.")
                Text("Quando o Tobi não entende uma linha de primeira, \(emphasis("uma inteligência artificial escolhe o alimento certo")). Isso custa dinheiro todo mês, pra cada pessoa que usa.")
                Text("\(emphasis("Não vendo seus dados e não tem anúncio.")) Quem paga a conta é a assinatura, e é ela que mantém o Tobi melhorando toda semana.")
            }
            .font(.system(size: 17))
            .lineSpacing(2)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .reveal(visible, order: 2)

            Text("Coloquei o preço pra caber no bolso. Espero que o Tobi te ajude a chegar lá :)")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 14)
                .reveal(visible, order: 3)

            signature
                .padding(.top, 10)
                .reveal(visible, order: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    /// O nome escreve da esquerda pra direita, como caneta no papel.
    private var signature: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("André")
                .font(.custom("SnellRoundhand-Bold", size: 42))
                .foregroundStyle(.indigo)
                .mask(alignment: .leading) {
                    Rectangle()
                        .padding(-24)
                        .scaleEffect(x: signed ? 1 : 0, anchor: .leading)
                }
            Text("criador do Tobi")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func emphasis(_ text: String) -> Text {
        Text(text).foregroundStyle(.primary).fontWeight(.medium)
    }
}
