import SwiftUI

/// "Por que o Tobi custa isso?": o André explica o preço, do jeito que ele falaria.
/// Abre do paywall. A foto é `founder.jpg` nos recursos; sem ela, o rostinho do Tobi.
struct FounderLetter: View {
    @Environment(\.dismiss) private var dismiss
    @State private var visible = false

    private static let photo = UIImage(named: "founder.jpg") ?? UIImage(named: "tobi-head")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let photo = Self.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipShape(.circle)
                        .overlay { Circle().strokeBorder(.white, lineWidth: 4) }
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                        .reveal(visible, order: 0)
                }

                Text("Oi, eu sou o André 👋")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .padding(.top, 26)
                    .reveal(visible, order: 1)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Eu fiz o Tobi e queria te contar, sem enrolação, por que ele custa isso.")
                    Text("Toda linha que o Tobi não entende de primeira vai pra uma inteligência artificial escolher o alimento certo. As buscas de marca e de código de barras passam pelos nossos servidores. Tudo isso tem custo todo mês, pra cada pessoa que usa.")
                    Text("Eu não vendo seus dados e não coloco anúncio no app. Quem paga a conta é a assinatura, e é ela que me deixa continuar melhorando o Tobi toda semana.")
                }
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .padding(.top, 14)
                .reveal(visible, order: 2)

                Text("Coloquei o preço pra caber no bolso e o Tobi continuar existindo. Espero que ele te ajude a chegar lá :)")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 16)
                    .reveal(visible, order: 3)

                Text("André, criador do Tobi")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.indigo)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                    .reveal(visible, order: 4)
            }
            .padding(.horizontal, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
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
        .onAppear { withAnimation(Motion.surface) { visible = true } }
    }
}
