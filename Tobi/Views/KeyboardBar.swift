import SwiftUI

/// Barra de baixo enquanto o teclado está aberto: calorias e ações rápidas.
struct KeyboardBar: View {
    let kcal: Int
    let isDictating: Bool
    let glass: Namespace.ID
    let onMic: () -> Void
    let onScan: () -> Void
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("🔥").font(.system(size: 14))
                Text(kcal.formatted())
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(kcal)))
            }
            .padding(.horizontal, 22)
            .frame(minWidth: 104)
            .frame(height: 44)
            .glassEffect(.regular, in: .capsule)
            .glassEffectID("totals", in: glass)
            .animation(Motion.quick, value: kcal)

            action(isDictating ? "Parar ditado" : "Ditar", isDictating ? "stop.fill" : "mic.fill",
                   isDictating ? .red : .blue, id: "mic", onMic)
                .symbolEffect(.pulse, isActive: isDictating)
                .contentTransition(.symbolEffect(.replace))
            action("Ler código de barras", "barcode.viewfinder", .purple, id: "scan", onScan)
            action("Nova linha", "plus", .orange, id: "add", onAdd)
            action("Fechar teclado", "keyboard.chevron.compact.down", .primary, id: "close", onDismiss)
        }
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
        KeyboardBar(kcal: 374, isDictating: false, glass: glass, onMic: {}, onScan: {}, onAdd: {}, onDismiss: {})
            .padding(24)
    }
}
