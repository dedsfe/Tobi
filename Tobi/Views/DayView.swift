import SwiftUI
import SwiftData
import PostHog

/// A tela principal: um bloco de notas do dia, com as calorias de cada linha do lado.
struct DayView: View {
    /// Só no onboarding (tela "Primeira refeição"): a mesma tela escrevendo sozinha (`FirstMealDemo`),
    /// sem as opções do topo, sem salvar nada; o "Continuar" aparece quando a demonstração termina.
    var onFirstMealDone: (() -> Void)?
    private var isDemo: Bool { onFirstMealDone != nil }
    @State private var demoDone = false
    /// Conta as linhas calculadas na demonstração, só pra vibrar a cada uma.
    @State private var demoLineDone = 0

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var parser = FoodParser(foods: [])
    @State private var parserReady = false
    @State private var loadedNote: DayNote?
    @State private var loadedDay: Date?
    @State private var dictationStart: Task<Void, Never>?
    @State private var showingScanner = false
    /// Linhas procurando produto de marca no Open Food Facts (mostram ✨).
    @State private var searching: Set<Int> = []
    private struct BrandSearch {
        let id: UUID
        let text: String
        let task: Task<Void, Never>
    }
    @State private var brandSearches: [Int: BrandSearch] = [:]
    /// Linha cujo "?" foi tocado: o toasterzinho explica o que não foi entendido.
    @State private var explaining: Explaining?
    /// Trecho sublinhado que foi tocado: as sugestões aparecem embaixo dele.
    @State private var suggesting: Suggesting?
    @State private var suggestionHeight: CGFloat = 240
    @State private var editMenuPresented = false

    struct Explaining {
        let id = UUID()
        let line: Int
        let lineText: String
        let rect: CGRect
    }

    struct Suggesting {
        let id = UUID()
        let line: Int
        let lineText: String
        /// O trecho (sem acento, minúsculo) e onde ele está na tela.
        let foodText: String
        let rect: CGRect
        var foods: [Food]
        var isAsking = false
        var message: String?
        var requestState: FoodRequestState = .idle
    }

    /// Cada texto passa pelo parser uma vez só. Sem isso, cada palavra ditada recalculava todas as
    /// linhas duas ou três vezes por redesenho (linha, total, barra) e a fala longa engasgava.
    @State private var estimateCache = EstimateCache()
    private func estimate(_ text: String) -> LineEstimate {
        parserReady ? estimateCache.estimate(text, with: parser) : .empty
    }
    private var estimates: [LineEstimate] { lines.map(estimate) }

    var body: some View {
        NoteEditor(
            text: $text,
            marks: lines.enumerated().map { index, line in
                let estimate = estimate(line)
                return LineMark(estimate: estimate, isSearching: searching.contains(index),
                                unknownSpans: isDemo ? [] : unknownPieces(estimate).map(parser.foodText))
            },
            controller: editor,
            placeholder: isDemo ? "" : "Comece a registrar suas refeições",
            onCaretLine: { caretMoved(from: $0, to: $1) },
            onUnknownTap: { line, span, rect in suggest(line: line, span: span, at: rect) },
            onMarkTap: { line, rect in
                guard lines.indices.contains(line) else { return }
                withAnimation(Motion.surface) {
                    suggesting = nil
                    explaining = Explaining(line: line, lineText: lines[line], rect: rect)
                }
            },
            onPlainTap: closeHelp,
            onEditMenuChange: editMenuChanged
        )
        // As refeições nunca aparecem na gravação de sessão do PostHog.
        .postHogMask()
        .overlay(alignment: .topLeading) { helpCard }
        .overlay(alignment: .topLeading) { suggestionBubble }
        // Marca invisível pros testes de interface: só existe com o banco em memória. Teste que
        // não acha a marca não digita nada (pode ser o app de verdade, com dados de verdade).
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("uiTestingMode")
            }
        }
        .allowsHitTesting(!isDemo)
        .background { Theme.background }
        // Barras que o sistema reconhece: o texto que passa por baixo some num desfoque progressivo.
        .safeAreaBar(edge: .top) { topBar }
        .safeAreaBar(edge: .bottom) { bottomBar }
        .scrollEdgeEffectStyle(.soft, for: .all)
        // Ajustes pode apagar tudo: relê o dia ao voltar.
        .sheet(isPresented: $showingSettings, onDismiss: load) { SettingsView() }
        .sheet(isPresented: $showingCalendar) { calendar }
        .fullScreenCover(isPresented: $showingScanner) {
            ScanSheet(onProduct: addScanned, onWriteInstead: { editor.focus() })
        }
        .task(id: brandProducts.map(\.barcode)) {
            await prepareParser()
            await cleanUpBrandProducts()
        }
        .task(id: day) { load() }
        .task {
            guard isDemo else { return }
            await playFirstMealDemo()
        }
        .onChange(of: text) {
            save()
            for (index, search) in brandSearches where lines[safe: index] != search.text {
                search.task.cancel()
                brandSearches[index] = nil
                searching.remove(index)
            }
            // O texto mudou: a ajuda aberta pode não valer mais pra linha.
            if let suggesting, lines[safe: suggesting.line] != suggesting.lineText { closeHelp() }
            if let explaining, !(lines.indices.contains(explaining.line) && estimate(lines[explaining.line]).hasUnknown) { closeHelp() }
        }
        .onChange(of: dictation.transcript) { _, spoken in applyDictation(spoken) }
        // O widget mostra o dia de hoje: acompanha o total, a meta e o fim da carga da base.
        .onChange(of: total) { publishToWidget() }
        .onChange(of: goal) { publishToWidget() }
        .onChange(of: parserReady) { publishToWidget() }
        // Fechou o teclado depois de anotar: bom momento pra perguntar o que está achando do app.
        .onChange(of: isEditing) { _, editing in
            guard !editing, !isDemo, parserReady, Calendar.current.isDateInToday(day) else { return }
            let recognized = estimates.filter { $0.items.contains(where: \.isRecognized) }.count
            FeedbackPrompt.shared.userFinishedLogging(recognizedLines: recognized)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                publishToWidget()
                stopDictation()
                cancelBrandSearches()
                closeHelp()
            }
        }
        .onDisappear {
            stopDictation()
            cancelBrandSearches()
            closeHelp()
        }
    }

    // MARK: - Barra de baixo

    private var total: Nutrition { estimates.map(\.total).total }

    private var bottomBar: some View {
        GlassEffectContainer(spacing: 6) {
            VStack(spacing: 10) {
                if let onFirstMealDone, demoDone {
                    Button(action: onFirstMealDone) {
                        Text("Continuar")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.indigo)
                    .transition(.emerge)
                }
                if showingGoals {
                    GoalsCard(total: total, goal: goal, isOpen: goalsOpen)
                        .onTapGesture { toggleGoals() }
                        .accessibilityIdentifier("goalsCard")
                        .transition(.emerge)
                }
                if let problem = dictation.problem, isEditing {
                    Text(problem)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .accessibilityIdentifier("dictationProblem")
                        .accessibilityValue(dictation.step)
                        .transition(.emerge)
                }
                if isEditing {
                    KeyboardBar(
                        total: total,
                        goal: goal,
                        dictation: dictation,
                        glass: glass,
                        onMic: toggleDictation,
                        onScan: { showingScanner = true },
                        onDismiss: { editor.dismissKeyboard() },
                        onTotals: {
                            editor.dismissKeyboard()
                            if !showingGoals { toggleGoals() }
                        }
                    )
                } else if isDemo {
                    TotalsBar(total: total, goal: goal, glass: glass, onTap: {})
                } else if isEmptyDay {
                    // Dia vazio: o convite é o botão. Quem chega aqui pela primeira vez sabe o que fazer.
                    addButton(expanded: true)
                } else {
                    HStack(spacing: 8) {
                        TotalsBar(total: total, goal: goal, glass: glass, onTap: toggleGoals)
                        addButton(expanded: false)
                    }
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
                    // Uma nuvem de luz atrás da barra, que sobe por cima das linhas.
                    VoiceGlow(dictation: dictation)
                        .frame(height: 260)
                        .transition(.emerge)
                }
            }
        }
        .animation(Motion.surface, value: dictation.isRecording)
        .animation(Motion.surface, value: demoDone)
        .sensoryFeedback(.impact(weight: .light), trigger: demoLineDone)
        .sensoryFeedback(.impact(weight: .light), trigger: showingGoals)
        .sensoryFeedback(trigger: dictation.isRecording) { _, recording in recording ? .start : .stop }
    }

    private var isEmptyDay: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// "+" pra começar a escrever com o teclado fechado: abre numa linha nova no fim da nota.
    private func addButton(expanded: Bool) -> some View {
        Button { editor.startNewEntry() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                if expanded {
                    Text("Adicionar comida")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(expanded ? Color.white : Color.primary)
            .padding(.horizontal, expanded ? 24 : 0)
            .frame(width: expanded ? nil : 48, height: 48)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(expanded ? .regular.tint(.indigo).interactive() : .regular.interactive(), in: .capsule)
        .glassEffectID("add", in: glass)
        .accessibilityLabel("Adicionar comida")
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
        dictationStart?.cancel()
        dictationStart = Task {
            guard !Task.isCancelled else { return }
            await dictation.start()
        }
    }

    private func stopDictation() {
        dictationStart?.cancel()
        dictationStart = nil
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
        VStack(spacing: 14) {
            header
            // Legenda da demonstração do onboarding, logo abaixo do topo.
            if isDemo { firstMealHint }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background { EdgeFade(edge: .top) }
    }

    private var header: some View {
        ZStack {
            HStack {
                Text("tobi")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.indigo)
                Spacer()
                // Na demonstração do onboarding o topo fica limpo: sem sequência, ajustes e dia.
                if !isDemo {
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
            }

            if !isDemo {
                Button { showingCalendar = true } label: {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.glass)
                .foregroundStyle(.primary)
            }
        }
    }

    /// Legenda da demonstração; vira um "pronto" quando a última linha é calculada.
    private var firstMealHint: some View {
        HStack(spacing: 8) {
            Image(systemName: demoDone ? "checkmark.circle.fill" : "pencil.line")
                .foregroundStyle(.indigo)
            // Cor fixa: no vidro, o texto em cor "adaptável" sumia no fundo claro.
            Text(demoDone ? "Pronto! O Tobi calculou tudo" : "É só escrever o que você comeu")
                .foregroundStyle(Color(uiColor: .label))
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .id(demoDone)
        .transition(.blurReplace)
        .animation(Motion.quick, value: demoDone)
    }

    /// Escreve `FirstMealDemo.lines` letra por letra. Enquanto a linha é escrita, ela mostra o ✨
    /// (o mesmo de "procurando"); no fim da linha o ✨ vira as calorias, com uma vibração leve.
    private func playFirstMealDemo() async {
        await prepareParser()
        guard !Task.isCancelled else { return }
        text = ""
        try? await Task.sleep(for: .seconds(0.8))
        for (index, line) in FirstMealDemo.lines.enumerated() {
            if index > 0 { text += "\n" }
            let isLabel = parser.estimate(line).isLabel
            if !isLabel { searching.insert(index) }
            for letter in line {
                guard !Task.isCancelled else { return }
                text.append(letter)
                try? await Task.sleep(for: FirstMealDemo.letterDelay)
            }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(Motion.quick) { _ = searching.remove(index) }
            if !isLabel { demoLineDone += 1 }
            try? await Task.sleep(for: FirstMealDemo.linePause)
        }
        withAnimation(Motion.surface) { demoDone = true }
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
        if let suggesting, suggesting.line != current { closeHelp() }
        if let explaining, explaining.line != current { closeHelp() }
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

    // MARK: - Ajuda pra linha que não entendeu

    private func unknownPieces(_ estimate: LineEstimate) -> [String] { estimate.unclearPieces }

    /// O trecho como a pessoa escreveu, com acento e maiúscula.
    private func written(_ foodText: String, in line: String) -> String {
        let range = NoteTextView.locate(foodText, in: line)
        return (line as NSString).substring(with: range).trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder private var helpCard: some View {
        if let explaining, lines.indices.contains(explaining.line) {
            let line = lines[explaining.line]
            let problems = unknownPieces(estimate(line)).enumerated().map { index, piece in
                let help = parser.help(for: piece)
                return UnknownHelpCard.Problem(id: index, written: written(help.foodText, in: line), help: help)
            }
            GeometryReader { geometry in
                let origin = geometry.frame(in: .global).origin
                let toastWidth: CGFloat = 270
                let x = min(max(explaining.rect.midX - origin.x - toastWidth / 2, 16), geometry.size.width - toastWidth - 16)
                let y = (explaining.rect.minY - origin.y > 54)
                    ? explaining.rect.minY - origin.y - 42
                    : explaining.rect.maxY - origin.y + 6
                UnknownHelpCard(problems: problems, onClose: closeHelp)
                    .offset(x: x, y: y)
                    .transition(.emerge(from: .topTrailing))
            }
            .id(explaining.id)
        }
    }

    @ViewBuilder private var suggestionBubble: some View {
        if let suggesting {
            GeometryReader { geometry in
                let origin = geometry.frame(in: .global).origin
                let bubbleWidth: CGFloat = 210
                let x = min(max(suggesting.rect.minX - origin.x, 16), geometry.size.width - bubbleWidth - 16)
                let below = suggesting.rect.maxY - origin.y + 6
                let y = below + suggestionHeight <= geometry.size.height - 12
                    ? below : max(12, suggesting.rect.minY - origin.y - suggestionHeight - 6)
                SuggestionBubble(suggestions: suggesting.foods, isAsking: suggesting.isAsking,
                                 message: suggesting.message, onPick: { food in pick(food, for: suggesting) },
                                 requestState: suggesting.requestState, onRequest: { requestFood(for: suggesting) })
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { suggestionHeight = $0 }
                .offset(x: x, y: y)
                .transition(.emerge(from: .topLeading))
            }
            .id(suggesting.id)
            .task(id: suggesting.id) { await improveSuggestions(for: suggesting) }
        }
    }

    /// A base responde na hora; a IA refina as opções sem interromper a escrita.
    private func suggest(line: Int, span: Int, at rect: CGRect) {
        guard parserReady, !isDemo, !editMenuPresented, scenePhase == .active, lines.indices.contains(line) else { return }
        let pieces = unknownPieces(estimate(lines[line]))
        guard pieces.indices.contains(span) else { return }
        let help = parser.help(for: pieces[span])
        var foods = help.suggestions.filter {
            FoodCorrection.replacing(help.foodText, in: lines[line], with: $0, parser: parser) != nil
        }
        if foods.isEmpty {
            foods = parser.candidates(for: help.foodText, limit: 3).filter {
                FoodCorrection.replacing(help.foodText, in: lines[line], with: $0, parser: parser) != nil
            }
        }
        let target = Suggesting(line: line, lineText: lines[line], foodText: help.foodText, rect: rect,
                                foods: foods, isAsking: true)
        withAnimation(Motion.surface) {
            explaining = nil
            suggesting = target
        }
    }

    private func improveSuggestions(for target: Suggesting) async {
        let base = parser
        do {
            // Só o trecho da comida sai do aparelho; a nota inteira não vai junto.
            let work = Task.detached(priority: .userInitiated) {
                var seen = Set<String>()
                let candidates = (target.foods + base.candidates(for: target.foodText, limit: 30)).filter {
                    seen.insert($0.name).inserted && FoodCorrection.replacing(target.foodText, in: target.lineText,
                                                                             with: $0, parser: base) != nil
                }
                return try await LineResolver.suggestions(for: target.foodText, among: candidates)
            }
            let foods = try await withTaskCancellationHandler {
                try await work.value
            } onCancel: { work.cancel() }
            guard !Task.isCancelled, suggesting?.id == target.id, lines[safe: target.line] == target.lineText,
                  scenePhase == .active else { return }
            suggesting?.isAsking = false
            if !foods.isEmpty { suggesting?.foods = Array(foods.prefix(4)) }
            else if suggesting?.foods.isEmpty == false { suggesting?.message = "Não encontrei outra opção na base." }
        } catch {
            guard !Task.isCancelled, suggesting?.id == target.id, lines[safe: target.line] == target.lineText else { return }
            suggesting?.isAsking = false
            suggesting?.message = "Não consegui buscar outras sugestões."
        }
    }

    /// Pedido explícito: o nome tocado entra na fila, sem modificar a refeição.
    private func requestFood(for target: Suggesting) {
        guard suggesting?.id == target.id, lines[safe: target.line] == target.lineText,
              target.requestState == .idle || target.requestState == .failed else { return }
        suggesting?.requestState = .sending
        let name = written(target.foodText, in: target.lineText)
        Task {
            do {
                let result = try await FoodRequests.send(name: name)
                guard suggesting?.id == target.id else { return }
                suggesting?.requestState = result == .sent ? .sent : .queued
                if result == .sent {
                    try? await Task.sleep(for: .seconds(Motion.foodRequestConfirmationDuration))
                    // Um pedido antigo nunca fecha as sugestões que a pessoa acabou de reabrir.
                    guard suggesting?.id == target.id, suggesting?.requestState == .sent else { return }
                    closeHelp()
                }
            } catch {
                guard suggesting?.id == target.id else { return }
                suggesting?.requestState = .failed
            }
        }
    }

    /// Troca só o trecho não entendido pelo nome do alimento escolhido; a quantidade fica.
    private func pick(_ food: Food, for target: Suggesting) {
        guard suggesting?.id == target.id, lines[safe: target.line] == target.lineText,
              let replaced = FoodCorrection.replacing(target.foodText, in: target.lineText, with: food, parser: parser) else { return }
        closeHelp()
        editor.replaceLine(target.line, with: replaced)
    }

    private func closeHelp() {
        guard explaining != nil || suggesting != nil else { return }
        withAnimation(Motion.exit) {
            explaining = nil
            suggesting = nil
        }
    }

    private func editMenuChanged(_ presented: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            editMenuPresented = presented
            if presented {
                explaining = nil
                suggesting = nil
            }
        }
    }

    // MARK: - Produtos de marca

    /// O que a base não reconheceu, procura no Open Food Facts. Só aceita produto vendido no Brasil
    /// com todas as palavras escritas no nome e que a IA confirma ser o que a pessoa escreveu;
    /// senão a linha continua "não sei". O número sempre vem do rótulo, nunca da IA.
    private func searchBrands(in index: Int) {
        guard lines.indices.contains(index), scenePhase == .active else { return }
        let line = lines[index]
        if brandSearches[index]?.text == line { return }
        brandSearches[index]?.task.cancel()
        let unknown = estimate(line).items.filter { !$0.isRecognized }.map(\.text)
        guard !unknown.isEmpty else { return }
        let searchedDay = day
        let id = UUID()
        searching.insert(index)
        let task = Task {
            defer {
                if brandSearches[index]?.id == id {
                    brandSearches[index] = nil
                    searching.remove(index)
                }
            }
            for piece in unknown {
                guard !Task.isCancelled, day == searchedDay, lines[safe: index] == line else { return }
                do {
                    // O Open Food Facts acha "prato" no "Arroz Prato Fino": só salva o que a IA confirmar.
                    let found = try await OpenFoodFacts.search(piece, limit: 5)
                    guard !found.isEmpty else { continue }
                    let match = try await LineResolver.confirmed(piece, among: found.map(\.name))
                    guard !Task.isCancelled, day == searchedDay, lines[safe: index] == line else { return }
                    if let match { save(found[match]) }
                } catch {
                    if Task.isCancelled { return }
                }
            }
        }
        brandSearches[index] = BrandSearch(id: id, text: line, task: task)
    }

    private func cancelBrandSearches() {
        brandSearches.values.forEach { $0.task.cancel() }
        brandSearches.removeAll()
        searching.removeAll()
    }

    private func prepareParser() async {
        let base = await FoodParser.prepared()
        guard !Task.isCancelled else { return }
        let foods = brandProducts.map(\.food)
        let build = Task.detached(priority: .userInitiated) { base.adding(foods) }
        let prepared = await withTaskCancellationHandler {
            await build.value
        } onCancel: {
            build.cancel()
        }
        guard !Task.isCancelled else { return }
        parser = prepared
        estimateCache.removeAll()
        parserReady = true
    }

    /// Uma vez só: apaga o produto que a busca por nome salvou errado antes da IA conferir.
    /// Sem rede, tenta de novo na próxima abertura.
    private func cleanUpBrandProducts() async {
        let defaults = UserDefaults.standard
        guard !isDemo, parserReady, !defaults.bool(forKey: BrandCleanup.doneKey) else { return }
        let notes = ((try? context.fetch(FetchDescriptor<DayNote>())) ?? []).map(\.text)
        let products = brandProducts.map { (barcode: $0.barcode, name: $0.name) }
        let base = parser
        let work = Task.detached(priority: .utility) {
            try await BrandCleanup.rejected(products: products, notes: notes, parser: base) { piece, name in
                try await LineResolver.confirmed(piece, among: [name]) != nil
            }
        }
        guard let rejected = try? await withTaskCancellationHandler(operation: { try await work.value },
                                                                    onCancel: { work.cancel() }),
              !Task.isCancelled else { return }
        for product in brandProducts where rejected.contains(product.barcode) { context.delete(product) }
        defaults.set(true, forKey: BrandCleanup.doneKey)
    }

    private func save(_ info: BrandProductInfo) {
        guard !brandProducts.contains(where: { $0.barcode == info.barcode }) else { return }
        context.insert(BrandProduct(info))
    }

    /// Produto escaneado: vai pra linha em foco se estiver vazia, senão numa linha nova logo abaixo.
    private func addScanned(_ info: BrandProductInfo, line text: String) {
        save(info)
        if let line = caretLine, lines.indices.contains(line),
           lines[line].trimmingCharacters(in: .whitespaces).isEmpty {
            editor.replaceLine(line, with: text, caretAtEnd: true)
        } else {
            editor.insertLine(after: caretLine ?? lines.count - 1, text: text)
        }
    }

    // MARK: - Persistência

    private func note(for day: Date) -> DayNote? {
        var descriptor = FetchDescriptor<DayNote>(predicate: #Predicate { $0.day == day })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func load() {
        guard !isDemo else { return }
        stopDictation()
        cancelBrandSearches()
        closeHelp()
        loadedNote = note(for: day)
        loadedDay = day
        text = loadedNote?.text ?? ""
    }

    /// Só o dia de hoje, já carregado e com a base pronta: antes disso o total ainda é zero.
    private func publishToWidget() {
        guard !isDemo, parserReady, loadedDay == day, Calendar.current.isDateInToday(day) else { return }
        WidgetBridge.publish(total, goal: goal)
    }

    private func save() {
        guard !isDemo, loadedDay == day else { return }
        if let note = loadedNote, note.day == day, !note.isDeleted {
            if note.text != text { note.text = text }
        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let note = DayNote(day: day, text: text)
            context.insert(note)
            loadedNote = note
        }
    }
}

/// Memória do parser por texto. Esvazia quando a base muda (produto de marca novo) e quando
/// limita as revisões antigas, sem esvaziar o dia inteiro durante o ditado.
@MainActor
final class EstimateCache {
    private var results: [String: LineEstimate] = [:]
    private var order: [String] = []
    private var oldest = 0
    private let capacity: Int
    private let byteLimit: Int
    private var retainedBytes = 0

    init(capacity: Int = 500, byteLimit: Int = 256_000) {
        self.capacity = max(1, capacity)
        self.byteLimit = max(1, byteLimit)
    }
    var count: Int { results.count }

    func estimate(_ text: String, with parser: FoodParser) -> LineEstimate {
        if let cached = results[text] { return cached }
        let cost = text.utf8.count
        if cost > byteLimit { return parser.estimate(text) }
        while !results.isEmpty && (results.count >= capacity || retainedBytes + cost > byteLimit) {
            let key = order[oldest]
            results.removeValue(forKey: key)
            retainedBytes -= key.utf8.count
            oldest += 1
            if oldest >= capacity || oldest * 2 >= order.count {
                order.removeFirst(oldest)
                oldest = 0
            }
        }
        let result = parser.estimate(text)
        results[text] = result
        retainedBytes += cost
        order.append(text)
        return result
    }

    func removeAll() {
        results.removeAll()
        order.removeAll()
        oldest = 0
        retainedBytes = 0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

#Preview {
    DayView()
        .modelContainer(for: DayNote.self, inMemory: true)
}
