import StoreKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("dailyGoal") private var goal = 2000
    @AppStorage("carbsShare") private var carbsShare = 0.5
    @AppStorage("proteinShare") private var proteinShare = 0.2
    @AppStorage("fatShare") private var fatShare = 0.3
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \DayNote.day) private var notes: [DayNote]

    @State private var confirmingErase = false
    @State private var eraseFailed = false
    @State private var managingSubscription = false
    @State private var restoring = false
    @State private var restoreResult: RestoreResult?
    #if DEBUG
    @State private var destination: DebugDestination?
    @State private var showingLetter = false
    @AppStorage("debugLocked") private var debugLocked = false
    #endif

    private enum RestoreResult: Identifiable {
        case restored, nothing
        var id: Self { self }
    }

    #if DEBUG
    private enum DebugDestination: Hashable {
        case animationLab, bodyLab
    }
    #endif

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Proteína em gramas por dia. Mexer nela tira (ou devolve) calorias de carbo e gordura na
    /// mesma proporção, pra divisão continuar fechando 100%.
    private var proteinGrams: Binding<Int> {
        Binding {
            Int((Double(goal) * proteinShare / 4).rounded())
        } set: { grams in
            let share = min(max(Double(grams) * 4 / Double(goal), 0.1), 0.6)
            let rest = carbsShare + fatShare
            let carbsPart = rest > 0 ? carbsShare / rest : 0.6
            proteinShare = share
            carbsShare = (1 - share) * carbsPart
            fatShare = (1 - share) * (1 - carbsPart)
        }
    }

    /// De 10% a 60% das calorias: fora disso o stepper trava em vez de apertar sem mudar nada.
    private var proteinRange: ClosedRange<Int> {
        Int((Double(goal) * 0.1 / 4).rounded(.up))...Int((Double(goal) * 0.6 / 4).rounded(.down))
    }

    private func grams(_ share: Double, perGram kcal: Double) -> String {
        "\(Int((Double(goal) * share / kcal).rounded())) g"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $goal, in: 1000...5000, step: 50) {
                        LabeledContent {
                            Text("\(goal.formatted()) kcal").monospacedDigit()
                        } label: {
                            Label("Calorias", systemImage: "flame.fill")
                        }
                    }
                    Stepper(value: proteinGrams, in: proteinRange, step: 5) {
                        LabeledContent {
                            Text("\(proteinGrams.wrappedValue) g").monospacedDigit()
                        } label: {
                            Label("Proteína", systemImage: "fish.fill")
                        }
                    }
                } header: {
                    Text("Metas do dia")
                } footer: {
                    Text("O resto vira \(grams(carbsShare, perGram: 4)) de carboidratos e \(grams(fatShare, perGram: 9)) de gordura.")
                        .monospacedDigit()
                }

                Section("Assinatura") {
                    Button { managingSubscription = true } label: {
                        Label("Gerenciar assinatura", systemImage: "creditcard.fill")
                    }
                    Button(action: restore) {
                        HStack {
                            Label("Restaurar compras", systemImage: "arrow.clockwise")
                            Spacer()
                            if restoring { ProgressView() }
                        }
                    }
                    .disabled(restoring)
                }

                Section {
                    ShareLink(item: NotesExport(notes: notes), preview: SharePreview("tobi.csv")) {
                        Label("Exportar refeições", systemImage: "square.and.arrow.up")
                    }
                    .disabled(notes.isEmpty)

                    Button(role: .destructive) { confirmingErase = true } label: {
                        Label("Apagar refeições", systemImage: "trash.fill")
                    }
                    .foregroundStyle(.red)
                    .disabled(notes.isEmpty)
                    .confirmationDialog("Apagar as refeições?",
                                        isPresented: $confirmingErase, titleVisibility: .visible) {
                        Button("Apagar refeições", role: .destructive, action: eraseAll)
                        Button("Cancelar", role: .cancel) { }
                    } message: {
                        Text("Apaga as refeições de todos os dias. Mantém suas metas e os produtos salvos. Não dá pra desfazer.")
                    }
                } header: {
                    Text("Seus dados")
                } footer: {
                    Text("Suas refeições ficam só neste iPhone. O exportar gera uma planilha com tudo.")
                }

                Section {
                    // O pedido automático da Apple só aparece 3 vezes por ano; o link abre sempre.
                    Link(destination: QuickActions.review) {
                        Label("Avaliar o Tobi", systemImage: "star.fill")
                    }
                    Link(destination: PaywallLinks.terms) {
                        Label("Termos de uso", systemImage: "doc.text.fill")
                    }
                    if let privacy = PaywallLinks.privacy {
                        Link(destination: privacy) {
                            Label("Política de privacidade", systemImage: "hand.raised.fill")
                        }
                    }
                } header: {
                    Text("Sobre")
                } footer: {
                    Text("Tobi \(version)")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }

                #if DEBUG
                Section("Debug") {
                    Button { destination = .animationLab } label: {
                        Label("Animações do Tobi", systemImage: "play.circle")
                    }
                    Button { destination = .bodyLab } label: {
                        Label("Tobi com corpinho", systemImage: "dog")
                    }
                    Button {
                        replayOnboarding(from: .welcome)
                    } label: {
                        Label("Ver onboarding de novo", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        replayOnboarding(from: .debugJump)
                    } label: {
                        Label("Abrir \(OnboardingStep.debugJump.debugName)", systemImage: "arrow.forward.to.line")
                    }
                    Button { showingLetter = true } label: {
                        Label("Carta do André", systemImage: "envelope")
                    }
                    Button {
                        dismiss()
                        FeedbackPrompt.shared.show(after: 0.7)
                    } label: {
                        Label("Pedido de opinião", systemImage: "heart.text.square")
                    }
                    Button(action: toggleLock) {
                        Label(debugLocked ? "Destravar o app" : "Travar o app (fim das 24h)",
                              systemImage: debugLocked ? "lock.open" : "lock")
                    }
                }
                #endif
            }
            .foregroundStyle(.primary)
            .scrollContentBackground(.hidden)
            .background { Theme.background }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .animationLab: TobiAnimationLabView()
                case .bodyLab: TobiAnimationLabView(bodyPreview: true)
                }
            }
            .sheet(isPresented: $showingLetter) { FounderLetter() }
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            // Cancelar, trocar de plano e ver a renovação: a folha da própria App Store.
            .manageSubscriptionsSheet(isPresented: $managingSubscription)
            .alert(item: $restoreResult) { result in
                switch result {
                case .restored:
                    Alert(title: Text("Assinatura restaurada"), message: Text("Tá tudo liberado de novo."))
                case .nothing:
                    Alert(title: Text("Nenhuma assinatura encontrada"),
                          message: Text("Não achei nenhuma assinatura do Tobi nessa conta da Apple."))
                }
            }
            .sensoryFeedback(trigger: restoreResult) { _, result in
                switch result {
                case .restored: .success
                case .nothing: .warning
                case nil: nil
                }
            }
            .alert("Não foi possível apagar as refeições", isPresented: $eraseFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Seus dados foram mantidos. Tente novamente.")
            }
        }
    }

    /// Confere na App Store se a conta já tem o Tobi e conta o resultado.
    private func restore() {
        restoring = true
        Task {
            let restored = await TobiStore.shared.restore()
            restoring = false
            restoreResult = restored ? .restored : .nothing
        }
    }

    #if DEBUG
    /// Fecha os Ajustes e trava (ou destrava) o app, como quando as 24 horas acabam.
    private func toggleLock() {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            debugLocked.toggle()
        }
    }

    /// Fecha os Ajustes primeiro e só depois troca a raiz do app pro onboarding.
    private func replayOnboarding(from step: OnboardingStep) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            UserDefaults.standard.set(step.rawValue, forKey: "onboardingStart")
            withAnimation(Motion.surface) {
                UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
            }
        }
    }
    #endif

    private func eraseAll() {
        notes.forEach(context.delete)
        do {
            try context.save()
        } catch {
            context.rollback()
            eraseFailed = true
        }
    }
}

/// CSV com uma linha por comida: dia, texto e o que o Tobi estimou.
struct NotesExport: Transferable {
    let rows: [NoteCSV.Row]

    @MainActor
    init(notes: [DayNote]) {
        rows = notes.map { NoteCSV.Row(day: $0.day, text: $0.text) }
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            // Só calcula ao compartilhar, fora da interface e com cancelamento.
            let work = Task.detached(priority: .utility) { try NoteCSV.data(export.rows) }
            return try await withTaskCancellationHandler {
                try await work.value
            } onCancel: {
                work.cancel()
            }
        }
        .suggestedFileName("tobi.csv")
    }
}

#if DEBUG
/// Cada animação do Tobi, uma de cada vez, para conferir no aparelho.
private enum TobiLabAnimation: String, CaseIterable, Identifiable {
    case idle, attentive, curious, presenting, celebrating
    case acknowledge, pet, yawn, sneeze, distraction, lick, blink, look, follow, eat

    var id: Self { self }

    var title: String {
        switch self {
        case .idle: "Idle"
        case .attentive: "Atento"
        case .curious: "Curioso"
        case .presenting: "Apresentando"
        case .celebrating: "Comemorando"
        case .acknowledge: "Respondeu"
        case .pet: "Carinho"
        case .yawn: "Bocejo"
        case .sneeze: "Espirro"
        case .distraction: "Se distrair"
        case .lick: "Lamber os beiços"
        case .blink: "Piscar"
        case .look: "Olhar pro lado"
        case .follow: "Seguir o dedo"
        case .eat: "Come-come"
        }
    }

    var detail: String {
        switch self {
        case .idle: "Alegre, com as manias aparecendo sozinhas a cada tanto."
        case .attentive: "Olhar focado e uma leve inclinação do rostinho. Telas sem resposta."
        case .curious: "Cabeça inclinada e olhar mais solto."
        case .presenting: "Olha pro cartão embaixo dele."
        case .celebrating: "Pulinhos e orelhas abanando, depois passa a apresentar."
        case .acknowledge: "Piscada, inclinação e ofegada quando você escolhe uma opção."
        case .pet: "Faz uma carinha fofa. No terceiro carinho, fica bem feliz por mais tempo."
        case .yawn: "Levanta o focinho, fecha os olhos e abre a boca."
        case .sneeze: "Ah... ah... tchim! E sacode a cabeça."
        case .distraction: "Algo chamou atenção do lado: olha e inclina a cabeça."
        case .lick: "A língua entra e varre de lado."
        case .blink: "Uma piscada."
        case .look: "Olha pro lado e volta."
        case .follow: "Toque e arraste pela tela: ele olha pro dedo e vira pro lado que você puxa."
        case .eat: "As comidas dão a volta por trás da cabeça e entram na boca. Sem parar."
        }
    }

    /// Estados ficam tocando; o resto é um gesto que dá pra repetir.
    var repeats: Bool { ![.idle, .attentive, .curious, .follow].contains(self) }
}

private struct TobiAnimationLabView: View {
    var bodyPreview = false
    @State private var isPlaying = true
    @State private var showModel = true
    @State private var animation = TobiLabAnimation.idle
    @State private var performance = TobiPerformance()
    @State private var snackReplay = 0
    @State private var blinkRequest = 0
    @State private var lookRequest = 0
    @State private var modelFailed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("Visual", selection: $showModel) {
                    Text("Emoji").tag(false)
                    Text("Modelo 3D").tag(true)
                }
                .pickerStyle(.segmented)

                if showModel && animation == .eat {
                    TobiSnackStage(isPlaying: isPlaying, replay: snackReplay)
                } else if showModel && !modelFailed {
                    TobiFaceView(isPlaying: isPlaying, blinkRequest: blinkRequest,
                                 lookRequest: lookRequest, isActive: scenePhase == .active,
                                 reduceMotion: reduceMotion, performance: performance,
                                 followsFinger: animation == .follow, showsBody: bodyPreview, onFailure: { modelFailed = true })
                        .frame(height: bodyPreview ? 340 : TobiStage.height)
                        .contentShape(.rect)
                        .onTapGesture { if animation == .pet { play(.pet) } }
                } else {
                    TobiIdleStage(isPlaying: isPlaying)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if showModel {
                        Menu {
                            Picker("Animação", selection: $animation) {
                                ForEach(TobiLabAnimation.allCases) { Text($0.title).tag($0) }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(animation.title)
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                        }
                        Text(animation.detail)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Idle")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                        Text("Respiração e balanço suave.")
                            .foregroundStyle(.secondary)
                    }
                    if modelFailed {
                        Text("Não foi possível carregar o modelo. O emoji foi mantido.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if reduceMotion {
                        Text("Movimento reduzido está ativado no iPhone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .tobiGlassSurface()

                HStack(spacing: 10) {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        GlassButtonLabel(title: isPlaying ? "Pausar" : "Reproduzir",
                                         symbol: isPlaying ? "pause.fill" : "play.fill")
                            .padding(.vertical, 10)
                    }
                    .animation(Motion.quick, value: isPlaying)
                    if showModel && !modelFailed && animation.repeats {
                        Button { play(animation) } label: {
                            GlassButtonLabel(title: "De novo", symbol: "arrow.counterclockwise")
                                .padding(.vertical, 10)
                        }
                        .disabled(!isPlaying)
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .foregroundStyle(.primary)
                .disabled(reduceMotion)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background { Theme.background }
        .navigationTitle(bodyPreview ? "Tobi com corpinho" : "Animações do Tobi")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: animation) { _, next in play(next) }
    }

    /// Escolher uma animação já toca ela. Fora o Idle, as manias só vêm quando pedidas.
    private func play(_ next: TobiLabAnimation) {
        performance.spontaneous = next == .idle
        switch next {
        case .idle, .acknowledge, .pet, .yawn, .sneeze, .distraction, .lick, .blink, .look, .follow, .eat:
            if performance.mood != .joyful { stage(.joyful) }
        case .attentive: stage(.attentive)
        case .curious: stage(.curious)
        case .presenting: stage(.presenting)
        case .celebrating: stage(.celebrating)
        }
        switch next {
        case .eat: snackReplay += 1
        case .acknowledge: performance.acknowledgements += 1
        case .pet: performance.pets += 1
        case .yawn: request(.yawn)
        case .sneeze: request(.sneeze)
        case .distraction: request(.distraction)
        case .lick: performance.licks += 1
        case .blink: blinkRequest += 1
        case .look: lookRequest += 1
        default: break
        }
    }

    private func stage(_ mood: TobiIdleBehavior.Mood) {
        performance.mood = mood
        performance.entering = true
        performance.scene += 1
    }

    private func request(_ quirk: TobiIdleBehavior.Quirk) {
        performance.quirkRequest = quirk
        performance.quirks += 1
    }
}


#endif

#Preview {
    SettingsView()
        .modelContainer(for: DayNote.self, inMemory: true)
}
