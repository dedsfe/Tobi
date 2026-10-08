import SwiftUI

/// O app travado: sem plano e sem as 24 horas, o Tobi no palco e os planos, sem X.
/// Destrava quando a compra ou a restauração dá certo, depois do confete.
struct LockedPaywall: View {
    let onUnlock: () -> Void

    @State private var tobi = TobiPerformance(mood: .attentive)

    var body: some View {
        VStack(spacing: 0) {
            TobiStage(performance: tobi, onPet: { tobi.pets += 1 })
                #if DEBUG
                .overlay(alignment: .topTrailing) {
                    // Só no Debug: volta pro app sem comprar, pra revisar a tela travada quantas vezes quiser.
                    Button("Destravar", systemImage: "lock.open", action: onUnlock)
                        .font(.system(size: 14, weight: .semibold))
                        .buttonStyle(.glass)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
                #endif
            PaywallStep(declined: .constant(false), onFinish: onUnlock)
                .frame(maxHeight: .infinity)
                .environment(\.tobiReactions, TobiReactions(
                    acknowledge: {
                        tobi.mood = .joyful
                        tobi.entering = false
                        tobi.acknowledgements += 1
                    },
                    celebrate: { perform(.celebrating) },
                    mood: perform
                ))
        }
        .background { Theme.background }
    }

    private func perform(_ mood: TobiIdleBehavior.Mood) {
        tobi.mood = mood
        tobi.entering = true
        tobi.scene += 1
    }
}
