import SwiftUI
import SwiftData

/// Uma linha da nota. O id estável deixa o foco sobreviver a inserções e remoções.
struct NoteLine: Identifiable, Equatable {
    let id = UUID()
    var text: String = ""
}

/// A tela principal: um bloco de notas do dia, com as calorias de cada linha do lado.
struct DayView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("dailyGoal") private var goal = 2000
    @Query private var notes: [DayNote]
    @Query private var brandProducts: [BrandProduct]

    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var lines: [NoteLine] = [NoteLine()]
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
    @State private var dictationTarget: (id: NoteLine.ID, base: String)?
    @State private var focusedLine: NoteLine.ID?
    /// Onde o cursor cai quando o foco muda por código (juntar/dividir linha). nil = fim.
    @State private var focusCursor: Int?

    /// Base oficial + produtos de marca que a pessoa já usou (refeito quando um produto entra).
    @State private var parser = FoodParser.shared
    @State private var showingScanner = false
    /// Linhas procurando produto de marca no Open Food Facts (mostram ✨).
    @State private var searching: Set<NoteLine.ID> = []

    private var estimates: [LineEstimate] { lines.map { parser.estimate($0.text) } }

    var body: some View {
        List {
            ForEach(lines) { line in
                LineRow(
                    text: text(of: line.id),
                    estimate: parser.estimate(line.text),
                    isSearching: searching.contains(line.id),
                    placeholder: line.id == lines.first?.id ? "Comece a registrar suas refeições..." : "",
                    isFocused: focusedLine == line.id,
                    dismissKeyboard: focusedLine == nil,
                    cursor: focusCursor,
                    onFocusChange: { lineFocusChanged(line.id, focused: $0) },
                    onReturn: { splitLine(line.id, before: $0, after: $1) },
                    onDeleteAtStart: { mergeWithPrevious(line.id) }
                )
                // Texto colado com várias linhas chega com "\n": vira várias linhas.
                .onChange(of: line.text) { _, text in
                    if text.contains("\n") { breakLine(line.id) }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
            }
            .onDelete { lines.remove(atOffsets: $0) }

            // Área vazia embaixo: tocar continua escrevendo na última linha.
            Color.clear
                .frame(height: 240)
                .contentShape(Rectangle())
                .onTapGesture { focusLastLine() }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.top, 16, for: .scrollContent)
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
        }
        .task(id: day) { load() }
        .onChange(of: lines) { save() }
        .onChange(of: focusedLine) { previous, line in
            if let previous, previous != line { compactLine(previous) }
            if line != nil, showingGoals { toggleGoals() }
            withAnimation(Motion.surface) { isEditing = line != nil }
            if line == nil, dictation.isRecording { stopDictation() }
        }
        .onChange(of: dictation.transcript) { _, spoken in applyDictation(spoken) }
    }

    // MARK: - Barra de baixo

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
                        isDictating: dictation.isRecording,
                        glass: glass,
                        onMic: toggleDictation,
                    onScan: { showingScanner = true },
                        onAdd: { insertLine(after: focusedLine ?? lines.last?.id ?? UUID()) },
                        onDismiss: { focusedLine = nil }
                    )
                } else {
                    TotalsBar(total: total, goal: goal, glass: glass, onTap: toggleGoals)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, isEditing ? 12 : 4)
        .padding(.top, 12)
        .background { EdgeFade(edge: .bottom) }
        .sensoryFeedback(.impact(weight: .light), trigger: showingGoals)
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
        guard let id = focusedLine, let line = lines.first(where: { $0.id == id }) else { return }
        dictationTarget = (id, line.text)
        Task { await dictation.start() }
    }

    private func stopDictation() {
        dictation.stop()
        dictationTarget = nil
    }

    private func applyDictation(_ spoken: String) {
        guard let target = dictationTarget, !spoken.isEmpty,
              let index = lines.firstIndex(where: { $0.id == target.id }) else { return }
        let base = target.base.trimmingCharacters(in: .whitespaces)
        lines[index].text = base.isEmpty ? spoken.lowercased() : "\(base) \(spoken.lowercased())"
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
                focusedLine = nil
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

    /// Binding pelo id, não pela posição: a linha pode sumir (apagar/juntar) com a tela ainda lendo.
    private func text(of id: NoteLine.ID) -> Binding<String> {
        Binding(
            get: { lines.first { $0.id == id }?.text ?? "" },
            set: { text in
                if let index = lines.firstIndex(where: { $0.id == id }), lines[index].text != text {
                    lines[index].text = text
                }
            }
        )
    }

    private func lineFocusChanged(_ id: NoteLine.ID, focused: Bool) {
        if focused {
            if focusedLine != id { focusedLine = id }
            focusCursor = nil
        } else {
            // Ao tocar outra linha, esta sai antes da outra entrar: espera pra não piscar "sem foco".
            Task { @MainActor in
                if focusedLine == id { focusedLine = nil }
            }
        }
    }

    /// Enter no meio da linha: o que vem depois do cursor desce pra uma linha nova.
    private func splitLine(_ id: NoteLine.ID, before: String, after: String) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        let line = NoteLine(text: after)
        lines[index].text = before
        lines.insert(line, at: index + 1)
        focusCursor = 0
        focusedLine = line.id
    }

    /// Apagar no começo da linha: junta com a de cima (linha vazia simplesmente some).
    private func mergeWithPrevious(_ id: NoteLine.ID) {
        guard let index = lines.firstIndex(where: { $0.id == id }), index > 0 else { return }
        let previous = lines[index - 1]
        let joint = previous.text.utf16.count
        lines[index - 1].text += lines[index].text
        lines[index].text = ""
        focusCursor = joint
        focusedLine = previous.id
        // Tira a linha só depois que a de cima pegou o foco, senão o teclado fecha no meio.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            lines.removeAll { $0.id == id }
        }
    }

    private func insertLine(after id: NoteLine.ID) {
        let index = (lines.firstIndex { $0.id == id } ?? lines.count - 1) + 1
        let line = NoteLine()
        lines.insert(line, at: index)
        // Espera a linha nova existir antes de mover o foco.
        focusCursor = nil
        focusedLine = line.id
    }

    /// Enter vira linha nova; texto colado com várias linhas vira várias linhas.
    private func breakLine(_ id: NoteLine.ID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        let parts = lines[index].text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines[index].text = parts[0]
        let pasted = parts.dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !pasted.isEmpty else {
            insertLine(after: id)
            return
        }
        let newLines = pasted.map { NoteLine(text: $0) }
        lines.insert(contentsOf: newLines, at: index + 1)
        focusCursor = nil
        focusedLine = newLines[newLines.count - 1].id
    }

    /// Ao sair da linha, enxuga o texto (ver `LineRewriter`).
    private func compactLine(_ id: NoteLine.ID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        let compact = LineRewriter.compact(lines[index].text)
        if compact != lines[index].text { lines[index].text = compact }
        searchBrands(in: id)
    }

    // MARK: - Produtos de marca

    /// O que a base não reconheceu, procura no Open Food Facts. Só aceita produto vendido no Brasil
    /// com todas as palavras escritas no nome; senão a linha continua "não sei".
    private func searchBrands(in id: NoteLine.ID) {
        guard let line = lines.first(where: { $0.id == id }) else { return }
        let unknown = parser.estimate(line.text).items.filter { !$0.isRecognized }.map(\.text)
        guard !unknown.isEmpty else { return }
        searching.insert(id)
        Task {
            for text in unknown {
                if let info = try? await OpenFoodFacts.search(text, limit: 1).first { save(info) }
            }
            searching.remove(id)
        }
    }

    private func save(_ info: BrandProductInfo) {
        guard !brandProducts.contains(where: { $0.barcode == info.barcode }) else { return }
        context.insert(BrandProduct(info))
    }

    /// Produto escaneado: vai pra linha em foco se estiver vazia, senão numa linha nova logo abaixo.
    private func addScanned(_ info: BrandProductInfo) {
        save(info)
        if let id = focusedLine, let index = lines.firstIndex(where: { $0.id == id }),
           lines[index].text.trimmingCharacters(in: .whitespaces).isEmpty {
            lines[index].text = info.name
        } else {
            let line = NoteLine(text: info.name)
            let index = focusedLine.flatMap { id in lines.firstIndex { $0.id == id } } ?? lines.count - 1
            lines.insert(line, at: index + 1)
            focusCursor = nil
            focusedLine = line.id
        }
    }

    private func focusLastLine() {
        if let last = lines.last, last.text.isEmpty {
            focusedLine = last.id
        } else {
            insertLine(after: lines.last?.id ?? UUID())
        }
    }

    // MARK: - Persistência

    private func note(for day: Date) -> DayNote? {
        let descriptor = FetchDescriptor<DayNote>(predicate: #Predicate { $0.day == day })
        return try? context.fetch(descriptor).first
    }

    private func load() {
        let text = note(for: day)?.text ?? ""
        let loaded = text.split(separator: "\n", omittingEmptySubsequences: false).map { NoteLine(text: String($0)) }
        lines = loaded.isEmpty ? [NoteLine()] : loaded
    }

    private func save() {
        let text = lines.map(\.text).joined(separator: "\n")
        if let note = note(for: day) {
            if note.text != text { note.text = text }
        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.insert(DayNote(day: day, text: text))
        }
    }
}

/// Uma linha: o texto à esquerda e as calorias à direita, como no app Notas.
struct LineRow: View {
    @Binding var text: String
    let estimate: LineEstimate
    var isSearching = false
    let placeholder: String
    let isFocused: Bool
    let dismissKeyboard: Bool
    let cursor: Int?
    var onFocusChange: (Bool) -> Void
    var onReturn: (String, String) -> Void
    var onDeleteAtStart: () -> Void

    private var font: UIFont { .systemFont(ofSize: 17, weight: estimate.isLabel ? .semibold : .regular) }

    var body: some View {
        let ascender = font.ascender
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            LineEditor(text: $text, font: font, isFocused: isFocused, dismissKeyboard: dismissKeyboard, cursor: cursor,
                       onFocusChange: onFocusChange, onReturn: onReturn, onDeleteAtStart: onDeleteAtStart)
                .alignmentGuide(.firstTextBaseline) { _ in ascender }
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(Font(font))
                            .foregroundStyle(Color(.placeholderText))
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 4) {
                // Procurando produto de marca no Open Food Facts.
                if isSearching {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse)
                        .transition(.scale.combined(with: .opacity))
                }
                Text("\(kcalLabel)\(Text(kcalLabel.isEmpty || kcalLabel == "?" ? "" : " cal").font(.system(size: 13)))")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(estimate.hasUnknown ? .tertiary : .secondary)
                    .contentTransition(.numericText())
            }
            .animation(Motion.quick, value: isSearching)
            .animation(Motion.quick, value: kcalLabel)
        }
    }

    private var kcalLabel: String {
        if estimate.isLabel || estimate.items.isEmpty { return "" }
        let kcal = Int(estimate.total.kcal.rounded())
        if estimate.items.allSatisfy({ !$0.isRecognized }) { return "?" }
        return estimate.hasUnknown ? "\(kcal.formatted())+" : kcal.formatted()
    }
}

#Preview {
    DayView()
        .modelContainer(for: DayNote.self, inMemory: true)
}
