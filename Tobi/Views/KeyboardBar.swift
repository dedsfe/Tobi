import SwiftUI

/// Barra de baixo enquanto o teclado está aberto: calorias e ações rápidas.
struct KeyboardBar: View {
    let kcal: Int
    let dictation: Dictation
    let glass: Namespace.ID
    let onMic: () -> Void
    let onScan: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("🔥").font(.system(size: 14))
                Text(kcal.formatted())
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(kcal)))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .frame(minWidth: 96)
            .frame(height: 44)
            .glassEffect(.regular, in: .capsule)
            .glassEffectID("totals", in: glass)
            .animation(Motion.quick, value: kcal)

            if dictation.isRecording {
                listening
            } else {
                action("Ditar", "mic.fill", .blue, id: "mic", onMic)
                action("Ler código de barras", "barcode.viewfinder", .purple, id: "scan", onScan)
            }
            action("Fechar teclado", "keyboard.chevron.compact.down", .primary, id: "close", onDismiss)
        }
    }

    /// Enquanto dita, o microfone engole os vizinhos e vira uma cápsula viva: a voz em barrinhas
    /// e o botão de parar.
    private var listening: some View {
        Button(action: onMic) {
            HStack(spacing: 12) {
                VoiceBars(dictation: dictation)
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("mic", in: glass)
        .accessibilityLabel("Parar ditado")
    }

    private func action(_ title: String, _ icon: String, _ color: Color, id: String,
                        _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID(id, in: glass)
        .accessibilityLabel(title)
    }
}

#Preview {
    @Previewable @Namespace var glass
    ZStack {
        Theme.background
        KeyboardBar(kcal: 374, dictation: Dictation(), glass: glass, onMic: {}, onScan: {}, onDismiss: {})
            .padding(24)
    }
}
