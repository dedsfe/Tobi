import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("dailyGoal") private var goal = 2000
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \DayNote.day) private var notes: [DayNote]

    @State private var confirmingErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Meta diária") {
                    Stepper(value: $goal, in: 1000...5000, step: 50) {
                        Text("\(goal.formatted()) kcal").monospacedDigit()
                    }
                }

                Section {
                    NavigationLink { ChangelogView() } label: {
                        Label { Text("Histórico de alterações") } icon: {
                            Image(systemName: "list.bullet.rectangle.portrait.fill").foregroundStyle(.purple)
                        }
                    }
                    NavigationLink { AboutView() } label: {
                        Label { Text("Sobre o app") } icon: {
                            Image(systemName: "heart.fill").foregroundStyle(.pink)
                        }
                    }
                }

                Section {
                    ShareLink(item: NotesExport(notes: notes), preview: SharePreview("tobi.csv")) {
                        Label("Exportar dados", systemImage: "square.and.arrow.up")
                    }
                    .disabled(notes.isEmpty)

                    Button(role: .destructive) { confirmingErase = true } label: {
                        Label("Apagar todos os dados", systemImage: "trash.fill")
                    }
                    .foregroundStyle(.red)
                    .disabled(notes.isEmpty)
                }

                #if DEBUG
                Section("Debug") {
                    Button("Ver onboarding de novo", systemImage: "arrow.counterclockwise") {
                        replayOnboarding(from: .welcome)
                    }
                    Button("Abrir \(OnboardingStep.debugJump.debugName)", systemImage: "arrow.forward.to.line") {
                        replayOnboarding(from: .debugJump)
                    }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background { Theme.background }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .confirmationDialog("Apagar todas as refeições de todos os dias?",
                                isPresented: $confirmingErase, titleVisibility: .visible) {
                Button("Apagar tudo", role: .destructive, action: eraseAll)
            } message: {
                Text("Não dá pra desfazer.")
            }
        }
    }

    #if DEBUG
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
        try? context.save()
    }
}

/// CSV com uma linha por comida: dia, texto e o que o Tobi estimou.
struct NotesExport: Transferable {
    let csv: String

    @MainActor
    init(notes: [DayNote]) {
        let parser = FoodParser.shared
        var rows = ["data,linha,kcal,carboidratos_g,proteina_g,gordura_g"]
        for note in notes {
            let day = note.day.formatted(.iso8601.year().month().day())
            for line in note.text.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let n = parser.estimate(String(line)).total
                let text = "\"" + line.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                let numbers = [n.kcal, n.carbs, n.protein, n.fat].map { String(Int($0.rounded())) }
                rows.append(([day, text] + numbers).joined(separator: ","))
            }
        }
        csv = rows.joined(separator: "\n")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.csv.utf8) }
            .suggestedFileName("tobi.csv")
    }
}

private struct ChangelogView: View {
    var body: some View {
        List {
            Section("0.1.0") {
                Text("Escreva o que comeu como numa nota e veja as calorias de cada linha.")
                Text("Metas do dia com carboidratos, proteína, gordura e mais.")
                Text("Ditado por voz em português.")
                Text("Sequência de dias registrando.")
            }
        }
        .scrollContentBackground(.hidden)
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
        VStack(spacing: 12) {
            Text("tobi")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.indigo)
            Text("Contar calorias do jeito mais simples: escrevendo.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Versão \(version)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.background }
        .navigationTitle("Sobre o app")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: DayNote.self, inMemory: true)
}
