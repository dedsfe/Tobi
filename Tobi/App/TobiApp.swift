import SwiftUI
import SwiftData

@main
struct TobiApp: App {
    /// Nos testes de interface o app começa vazio e não mexe nos dados de verdade.
    private let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    /// Tela em que o onboarding abre. Só o atalho do Debug muda; volta pra boas-vindas ao terminar.
    @AppStorage("onboardingStart") private var onboardingStart = 0
    @State private var store = TobiStore.shared
    /// Tela travada na frente do app. Só sai pelo `unlock`, pra o confete da compra terminar antes.
    @State private var locked = false
    #if DEBUG
    /// O botão dos Ajustes trava e destrava o app na mão, sem esperar as 24 horas.
    @AppStorage("debugLocked") private var debugLocked = false
    #endif

    init() {
        // O Tobi é brasileiro: datas e números saem em pt-BR ("dezembro", "2.820") mesmo com o
        // iPhone em outra região. Precisa vir antes de qualquer formatação.
        UserDefaults.standard.set("pt_BR", forKey: "AppleLocale")
        // -resetOnboarding no esquema reabre o onboarding a cada abertura.
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
        }
    }

    /// Sem plano e sem as 24 horas, o app trava. No Debug, quem manda é o botão dos Ajustes.
    private var shouldLock: Bool {
        guard didCompleteOnboarding, !inMemory else { return false }
        #if DEBUG
        return debugLocked
        #else
        return !store.hasAccess
        #endif
    }

    private func unlock() {
        #if DEBUG
        debugLocked = false
        #endif
        withAnimation(Motion.surface) { locked = false }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if didCompleteOnboarding || inMemory {
                    if locked {
                        LockedPaywall(onUnlock: unlock)
                            .transition(.emerge)
                    } else {
                        DayView()
                            .transition(.emerge)
                    }
                } else {
                    OnboardingView(start: OnboardingStep(rawValue: onboardingStart) ?? .welcome) {
                        onboardingStart = 0
                        withAnimation(Motion.surface) { didCompleteOnboarding = true }
                    }
                }
            }
            .onChange(of: shouldLock, initial: true) { _, lock in
                if lock { withAnimation(Motion.surface) { locked = true } }
            }
            .task { await store.refreshAccess() }
        }
        .modelContainer(for: [DayNote.self, BrandProduct.self], inMemory: inMemory)
    }
}
