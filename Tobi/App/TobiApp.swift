import SwiftUI
import SwiftData

@main
struct TobiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(TobiAppDelegate.self) private var appDelegate
    /// Nos testes de interface o app começa vazio e não mexe nos dados de verdade.
    private let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    /// Tela em que o onboarding abre. Só o atalho do Debug muda; volta pra boas-vindas ao terminar.
    @AppStorage("onboardingStart") private var onboardingStart = 0
    @State private var store = TobiStore.shared
    @State private var feedback = FeedbackPrompt.shared
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
        Analytics.start()
        // -resetOnboarding no esquema reabre o onboarding a cada abertura.
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
        }
    }

    /// `-onboardingShot paywall`: abre essa tela do onboarding pros prints da App Store. Só no Debug.
    private static var screenshotStep: OnboardingStep? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-onboardingShot"), args.indices.contains(index + 1) else { return nil }
        return OnboardingStep.allCases.first { $0.analyticsName == args[index + 1] }
        #else
        return nil
        #endif
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
                if inMemory, let step = Self.screenshotStep {
                    // Prints da App Store: a tela do onboarding no modo de teste, sem salvar nada.
                    OnboardingView(start: step) {}
                } else if didCompleteOnboarding || inMemory {
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
            .task(id: didCompleteOnboarding) {
                // O aviso de rastreamento só vem depois do onboarding, com o app já em uso.
                guard didCompleteOnboarding, !inMemory else { return }
                await Tracking.request()
            }
            .sheet(isPresented: $feedback.isShowing) { FeedbackSheet() }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    await FoodRequests.shared.retryPending()
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                }
            }
            .task {
                FeedbackClient.retryPending()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-feedbackPrompt") { feedback.show(after: 1) }
                #endif
            }
            .task {
                // Atalho do ícone tocado com o app fechado: abre depois que a tela apareceu.
                try? await Task.sleep(for: .seconds(0.6))
                QuickActions.performPending()
            }
            .task {
                async let parser = FoodParser.prepared()
                await store.refreshAccess()
                _ = await parser
            }
        }
        .modelContainer(for: [DayNote.self, BrandProduct.self], inMemory: inMemory)
    }
}
