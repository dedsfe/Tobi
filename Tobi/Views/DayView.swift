import SwiftUI
import SwiftData

/// A tela principal: um bloco de notas do dia, com as calorias de cada linha do lado.
struct DayView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("dailyGoal") private var goal = 2000
    @Query private var notes: [DayNote]
    @Query private var brandProducts: [BrandProduct]

    @State private var day = Calendar.current.startOfDay(for: .now)
    /// O dia inteiro, uma linha por "\n" (é assim que fica salvo).
    @State private var text = ""
    private var lines: [String] { text.components(separatedBy: "\n") }
    @State private var showingSettings = false
    @State private var showingCalendar = false
    @State private var showingGoals = false
    /// Conteúdo do card de Metas; apaga antes do card sair (ver `Motion.close`).
    @State private var goalsOpen = false
    /// Espelho do foco, trocado dentro de `withAnimation` pra barra de baixo morfar junto com o teclado.
    @State private var isEditing = false
    @Namespace private var glass
    @State private var dictation = Dictation()
    /// Linha que recebe o ditado e o texto que ela tinha antes de começar a falar.
    @State private var dictationTarget: (line: Int, base: String)?
    @State private var editor = NoteEditorController()
    /// Linha do cursor (nil = sem teclado) e quantas linhas havia nesse momento.
    @State private var caretLine: Int?
    @State private var lineCountAtCaret = 0

    /// Base oficial + produtos de marca que a pessoa já usou (refeito quando um produto entra).
    @State private var parser = FoodParser.shared
    @State private var showingScanner = false
    /// Linhas procurando produto de marca no Open Food Facts (mostram ✨).
    @State private var searching: Set<Int> = []

    /// Cada texto passa pelo parser uma vez só. Sem isso, cada palavra ditada recalculava todas as
    /// linhas duas ou três vezes por redesenho (linha, total, barra) e a fala longa engasgava.
    @State private var estimateCache = EstimateCache()
    private func estimate(_ text: String) -> LineEstimate { estimateCache.estimate(text, with: parser) }
    private var estimates: [LineEstimate] { lines.map(estimate) }

    var body: some View {
        NoteEditor(
            text: $text,
            marks: lines.enumerated().map { index, line in
                LineMark(estimate: estimate(line), isSearching: searching.contains(index))
            },
            controller: editor,
            placeholder: "Comece a registrar suas refeições...",
            onCaretLine: { caretMoved(from: $0, to: $1) }
        )
        // O texto passa por baixo das barras; o UITextView recebe a altura delas como margem.
        .ignoresSafeArea(.container, edges: .vertical)
        .background { Theme.background }
        // Barras que o sistema reconhece: o texto que passa por baixo some num desfoque progressivo.
        .safeAreaBar(edge: .top) { topBar }
        .safeAreaBar(edge: .bottom) { bottomBar }
        .scrollEdgeEffectStyle(.soft, for: .all)
        // Ajustes pode apagar tudo: relê o dia ao voltar.
        .sheet(isPresented: $showingSettings, onDismiss: load) { SettingsView() }
        .sheet(isPresented: $showingCalendar) { calendar }
        .sheet(isPresented: $showingScanner) {
            ScanSheet { product in addScanned(product) }
        }
        .onChange(of: brandProducts.map(\.barcode), initial: true) {
            parser = FoodParser.shared.adding(brandProducts.map(\.food))
            estimateCache.removeAll()
        }
        .task(id: day) { load() }
        .onChange(of: text) { save() }
        .onChange(of: dictation.transcript) { _, spoken in applyDictation(spoken) }
    }

    // MARK: - Barra de baixo

    /// Quanto da luz do ditado fica escondida atrás do teclado.
    private static let glowUnderKeyboard: CGFloat = 120

    private var total: Nutrition { estimates.map(\.total).total }

    private var bottomBar: some View {
        GlassEffectContainer(spacing: 6) {
            VStack(spacing: 10) {
                if showingGoals {
                    GoalsCard(total: total, goal: goal, isOpen: goalsOpen)
                        .onTapGesture { toggleGoals() }
                        .transition(.emerge)
                }
                if isEditing {
                    KeyboardBar(
                        kcal: Int(total.kcal.rounded()),
                        dictation: dictation,
                        glass: glass,
                        onMic: toggleDictation,
                    onScan: { showingScanner = true },
                        onAdd: { editor.insertLine(after: caretLine ?? lines.count - 1) },
                        onDismiss: { editor.dismissKeyboard() }
                    )
                } else {
                    TotalsBar(total: total, goal: goal, glass: glass, onTap: toggleGoals)
                }
            }
        }
        .padding(.horizontal, isEditing ? 20 : 32)
        .padding(.bottom, isEditing ? 12 : 4)
        .padding(.top, 12)
        .background(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                EdgeFade(edge: .bottom)
                if dictation.isRecording {
                    // A luz nasce atrás do teclado e sobe por cima das linhas: continua por baixo
                    // dele (aparece nos cantos arredondados), sem corte reto em lugar nenhum.
                    VoiceGlow(dictation: dictation)
                        .frame(height: 260 + Self.glowUnderKeyboard)
                        .offset(y: Self.glowUnderKeyboard)
                        .transition(.emerge)
                }
            }
        }
        .animation(Motion.surface, value: dictation.isRecording)
        .sensoryFeedback(.impact(weight: .light), trigger: showingGoals)
        .sensoryFeedback(trigger: dictation.isRecording) { _, recording in recording ? .start : .stop }
    }

    private func toggleGoals() {
        if showingGoals {
            Motion.close(content: { goalsOpen = false }, surface: { showingGoals = false })
        } else {
            goalsOpen = true
            withAnimation(Motion.surface) { showingGoals = true }
        }
    }

    // MARK: - Ditado

    private func toggleDictation() {
        if dictation.isRecording {
            stopDictation()
            return
        }
        guard let line = caretLine, lines.indices.contains(line) else { return }
        dictationTarget = (line, lines[line])
        Task { await dictation.start() }
    }

    private func stopDictation() {
        dictation.stop()
        dictationTarget = nil
    }

    private func applyDictation(_ spoken: String) {
        guard let target = dictationTarget, !spoken.isEmpty, lines.indices.contains(target.line) else { return }
        let base = target.base.trimmingCharacters(in: .whitespaces)
        editor.replaceLine(target.line, with: base.isEmpty ? spoken.lowercased() : "\(base) \(spoken.lowercased())",
                           caretAtEnd: true)
    }

    // MARK: - Topo

    private var topBar: some View {
        ZStack {
            HStack {
                Text("tobi")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.indigo)
                Spacer()
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Text("🔥").font(.system(size: 14))
                        Text(streak.formatted())
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    Button("Ajustes", systemImage: "gearshape.fill") { showingSettings = true }
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassEffect(.regular.interactive(), in: .capsule)
            }

            Button { showingCalendar = true } label: {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background { EdgeFade(edge: .top) }
    }

    private var calendar: some View {
        DatePicker("Dia", selection: Binding(
            get: { day },
            set: { picked in
                editor.dismissKeyboard()
                day = Calendar.current.startOfDay(for: picked)
                showingCalendar = false
            }
        ), in: ...Date.now, displayedComponents: .date)
        .datePickerStyle(.graphical)
        .padding()
        .presentationDetents([.medium])
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Hoje" }
        if calendar.isDateInYesterday(day) { return "Ontem" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Dias seguidos com algo escrito, contando até hoje (ou até ontem, se hoje ainda está vazio).
    private var streak: Int {
        let calendar = Calendar.current
        let written = Set(notes
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { calendar.startOfDay(for: $0.day) })
        var cursor = calendar.startOfDay(for: .now)
        if !written.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor)! }
        var count = 0
        while written.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    // MARK: - Edição

    private func caretMoved(from previous: Int?, to current: Int?) {
        // Ao sair de uma linha, enxuga ela. Só quando dá pra ter certeza de que o número ainda é
        // a mesma linha: nada mudou de tamanho, ou foi um enter logo abaixo dela.
        let count = lines.count
        if let previous, previous != current, lines.indices.contains(previous),
           count == lineCountAtCaret || (count == lineCountAtCaret + 1 && current == previous + 1) {
            compactLine(previous)
        }
        caretLine = current
        lineCountAtCaret = count
        if current != nil, showingGoals { toggleGoals() }
        if (current != nil) != isEditing { withAnimation(Motion.surface) { isEditing = current != nil } }
        if current == nil, dictation.isRecording { stopDictation() }
    }

    /// Ao sair da linha, enxuga o texto (ver `LineRewriter`).
    private func compactLine(_ index: Int) {
        let compact = LineRewriter.compact(lines[index])
        if compact != lines[index] { editor.replaceLine(index, with: compact) }
        searchBrands(in: index)
    }

    // MARK: - Produtos de marca

    /// O que a base não reconheceu, procura no Open Food Facts. Só aceita produto vendido no Brasil
    /// com todas as palavras escritas no nome; senão a linha continua "não sei".
    /// Ordem de quem responde: base local (redes, TACO, IBGE) → Open Food Facts → IA (quando entrar).
    /// A IA só interpreta a frase e aponta itens da base; número inventado nunca entra.
    private func searchBrands(in index: Int) {
        guard lines.indices.contains(index) else { return }
        let unknown = estimate(lines[index]).items.filter { !$0.isRecognized }.map(\.text)
        guard !unknown.isEmpty else { return }
        searching.insert(index)
        Task {
            for text in unknown {
                if let info = try? await OpenFoodFacts.search(text, limit: 1).first { save(info) }
            }
            searching.remove(index)
        }
    }

    private func save(_ info: BrandProductInfo) {
        guard !brandProducts.contains(where: { $0.barcode == info.barcode }) else { return }
        context.insert(BrandProduct(info))
    }

    /// Produto escaneado: vai pra linha em foco se estiver vazia, senão numa linha nova logo abaixo.
    private func addScanned(_ info: BrandProductInfo) {
        save(info)
        if let line = caretLine, lines.indices.contains(line),
           lines[line].trimmingCharacters(in: .whitespaces).isEmpty {
            editor.replaceLine(line, with: info.name, caretAtEnd: true)
        } else {
            editor.insertLine(after: caretLine ?? lines.count - 1, text: info.name)
        }
    }

    // MARK: - Persistência

    private func note(for day: Date) -> DayNote? {
        let descriptor = FetchDescriptor<DayNote>(predicate: #Predicate { $0.day == day })
        return try? context.fetch(descriptor).first
    }

    private func load() {
        text = note(for: day)?.text ?? ""
    }

    private func save() {
        if let note = note(for: day) {
            if note.text != text { note.text = text }
        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.insert(DayNote(day: day, text: text))
        }
    }
}

/// Memória do parser por texto. Esvazia quando a base muda (produto de marca novo) e quando
/// passa de 500 textos, pra não crescer sem fim durante o ditado.
@MainActor
final class EstimateCache {
    private var results: [String: LineEstimate] = [:]

    func estimate(_ text: String, with parser: FoodParser) -> LineEstimate {
        if let cached = results[text] { return cached }
        if results.count > 500 { results.removeAll(keepingCapacity: true) }
        let result = parser.estimate(text)
        results[text] = result
        return result
    }

    func removeAll() { results.removeAll() }
}

#Preview {
    DayView()
        .modelContainer(for: DayNote.self, inMemory: true)
}
