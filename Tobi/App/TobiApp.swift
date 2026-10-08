import SwiftUI
import SwiftData

@main
struct TobiApp: App {
    /// Nos testes de interface o app começa vazio e não mexe nos dados de verdade.
    private let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    /// Tela em que o onboarding abre. Só o atalho do Debug muda; volta pra boas-vindas ao terminar.
    @AppStorage("onboardingStart") private var onboardingStart = 0

    init() {
        // O Tobi é brasileiro: datas e números saem em pt-BR ("dezembro", "2.820") mesmo com o
        // iPhone em outra região. Precisa vir antes de qualquer formatação.
        UserDefaults.standard.set("pt_BR", forKey: "AppleLocale")
        // -resetOnboarding no esquema reabre o onboarding a cada abertura.
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            if didCompleteOnboarding || inMemory {
                DayView()
                    .transition(.emerge)
            } else {
                OnboardingView(start: OnboardingStep(rawValue: onboardingStart) ?? .welcome) {
                    onboardingStart = 0
                    withAnimation(Motion.surface) { didCompleteOnboarding = true }
                }
            }
        }
        .modelContainer(for: [DayNote.self, BrandProduct.self], inMemory: inMemory)
    }
}
