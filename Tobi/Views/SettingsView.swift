import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("dailyGoal") private var goal = 2000
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \DayNote.day) private var notes: [DayNote]

    @State private var confirmingErase = false
    @State private var eraseFailed = false
    @State private var destination: SettingsDestination?
    @State private var managingSubscription = false
    @State private var restoring = false
    @State private var restoreResult: RestoreResult?
    #if DEBUG
    @AppStorage("debugLocked") private var debugLocked = false
    #endif

    private enum RestoreResult: Identifiable {
        case restored, nothing
        var id: Self { self }
    }

    private enum SettingsDestination: Hashable {
        case changelog, about
        #if DEBUG
        case animationLab, bodyLab
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meta diária") {
                    Stepper(value: $goal, in: 1000...5000, step: 50) {
                        Text("\(goal.formatted()) kcal").monospacedDigit()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .glassEffect(.regular, in: .capsule)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                Section {
                    Button { managingSubscription = true } label: {
                        settingsLabel("Gerenciar assinatura", systemImage: "creditcard.fill", navigates: true)
                    }
                    Button(action: restore) {
                        HStack(spacing: 12) {
                            settingsLabel("Restaurar compras", systemImage: "arrow.clockwise")
                            if restoring { ProgressView() }
                        }
                    }
                    .disabled(restoring)
                } header: {
                    Text("Assinatura").foregroundStyle(.secondary)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .foregroundStyle(.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                Section {
                    Button { destination = .changelog } label: {
                        settingsLabel("Histórico de alterações", systemImage: "list.bullet.rectangle.portrait.fill", navigates: true)
                    }
                    Button { destination = .about } label: {
                        settingsLabel("Sobre o app", systemImage: "heart.fill", navigates: true)
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .foregroundStyle(.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                Section {
                    ShareLink(item: NotesExport(notes: notes), preview: SharePreview("tobi.csv")) {
                        settingsLabel("Exportar dados", systemImage: "square.and.arrow.up")
                    }
                    .disabled(notes.isEmpty)

                    Button(role: .destructive) { confirmingErase = true } label: {
                        settingsLabel("Apagar todos os dados", systemImage: "trash.fill")
                    }
                    .foregroundStyle(.red)
                    .disabled(notes.isEmpty)
                    .confirmationDialog("Apagar as refeições?",
                                        isPresented: $confirmingErase, titleVisibility: .visible) {
                        Button("Apagar refeições", role: .destructive, action: eraseAll)
                        Button("Cancelar", role: .cancel) { }
                    } message: {
                        Text("Apaga as refeições de todos os dias. Mantém sua meta e os produtos salvos. Não dá pra desfazer.")
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .foregroundStyle(.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                #if DEBUG
                Section {
                    Button { destination = .animationLab } label: {
                        settingsLabel("Animações do Tobi", systemImage: "play.circle", navigates: true)
                    }
                    Button { destination = .bodyLab } label: {
                        settingsLabel("Tobi com corpinho", systemImage: "dog", navigates: true)
                    }
                    Button {
                        replayOnboarding(from: .welcome)
                    } label: {
                        settingsLabel("Ver onboarding de novo", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        replayOnboarding(from: .debugJump)
                    } label: {
                        settingsLabel("Abrir \(OnboardingStep.debugJump.debugName)", systemImage: "arrow.forward.to.line")
                    }
                    Button(action: toggleLock) {
                        settingsLabel(debugLocked ? "Destravar o app" : "Travar o app (fim das 24h)",
                                      systemImage: debugLocked ? "lock.open" : "lock")
                    }
                } header: {
                    Text("Debug").foregroundStyle(.secondary)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .foregroundStyle(.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                #endif
            }
            .scrollContentBackground(.hidden)
            .background { Theme.background }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .changelog: ChangelogView()
                case .about: AboutView()
                #if DEBUG
                case .animationLab: TobiAnimationLabView()
                case .bodyLab: TobiAnimationLabView(bodyPreview: true)
                #endif
                }
            }
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

    private func settingsLabel(_ title: String, systemImage: String, navigates: Bool = false) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if navigates {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .padding(.horizontal, 6)
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

private struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("0.1.0")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                Text("Escreva o que comeu como numa nota e veja as calorias de cada linha.")
                Text("Metas do dia com carboidratos, proteína, gordura e mais.")
                Text("Ditado por voz em português.")
                Text("Sequência de dias registrando.")
            }
            .tobiGlassSurface()
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background { Theme.background }
        .navigationTitle("Histórico de alterações")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TobiStage()
                VStack(spacing: 12) {
                    Text("tobi")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.indigo)
                    Text("Contar calorias do jeito mais simples: escrevendo.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Text("Versão \(version)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .tobiGlassSurface(alignment: .center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background { Theme.background }
        .navigationTitle("Sobre o app")
        .navigationBarTitleDisplayMode(.inline)
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
