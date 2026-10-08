import SwiftUI
import UIKit

/// O bloco de notas do dia num campo só, como o app Notas: seleção atravessa linhas, selecionar
/// tudo e apagar, enter, colar várias linhas e desfazer são os do próprio sistema. As calorias de
/// cada linha ficam numa coluna à direita que rola junto com o texto.
struct NoteEditor: UIViewRepresentable {
    @Binding var text: String
    /// Uma por linha do texto, na mesma ordem.
    let marks: [LineMark]
    let controller: NoteEditorController
    let placeholder: String
    /// O cursor mudou de linha (nil = sem teclado). Recebe a linha de antes e a de agora.
    var onCaretLine: (_ previous: Int?, _ current: Int?) -> Void

    func makeUIView(context: Context) -> NoteTextView {
        let view = NoteTextView.make()
        view.delegate = context.coordinator
        view.placeholder = placeholder
        view.onProgrammaticChange = { [weak coordinator = context.coordinator] text in
            coordinator?.textChanged(text)
        }
        controller.textView = view
        return view
    }

    func updateUIView(_ view: NoteTextView, context: Context) {
        context.coordinator.parent = self
        controller.textView = view
        if view.text != text { view.setTextKeepingCaret(text) }
        view.marks = marks
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteEditor
        private var caretLine: Int?

        init(parent: NoteEditor) { self.parent = parent }

        func textChanged(_ text: String) {
            if parent.text != text { parent.text = text }
        }

        func textViewDidChange(_ textView: UITextView) {
            textChanged(textView.text)
            reportCaret(of: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) { reportCaret(of: textView) }
        func textViewDidBeginEditing(_ textView: UITextView) { reportCaret(of: textView) }

        func textViewDidEndEditing(_ textView: UITextView) {
            let previous = caretLine
            caretLine = nil
            // Avisa depois do ciclo atual: o foco pode mudar no meio de uma atualização da tela.
            Task { @MainActor in self.parent.onCaretLine(previous, nil) }
        }

        private func reportCaret(of textView: UITextView) {
            guard textView.isFirstResponder, let view = textView as? NoteTextView else { return }
            let line = view.caretLine
            guard line != caretLine else { return }
            let previous = caretLine
            caretLine = line
            Task { @MainActor in self.parent.onCaretLine(previous, line) }
        }
    }
}

/// O que a coluna da direita mostra numa linha.
struct LineMark: Equatable {
    let estimate: LineEstimate
    var isSearching = false
}

/// Por onde o DayView mexe no texto sem ser pelo teclado: ditado, código de barras, botão +.
@MainActor
final class NoteEditorController {
    fileprivate weak var textView: NoteTextView?

    /// Linha onde está o cursor (nil = sem teclado).
    var caretLine: Int? {
        guard let textView, textView.isFirstResponder else { return nil }
        return textView.caretLine
    }

    /// Troca o texto de uma linha. O cursor fica onde estava (ou no fim dela, se pedido).
    func replaceLine(_ index: Int, with text: String, caretAtEnd: Bool = false) {
        textView?.replaceLine(index, with: text, caretAtEnd: caretAtEnd)
    }

    /// Linha nova logo abaixo de `index`, com o cursor nela.
    func insertLine(after index: Int, text: String = "") {
        textView?.insertLine(after: index, text: text)
    }

    /// Cursor no fim do texto, com teclado.
    func focusEnd() {
        guard let textView else { return }
        textView.becomeFirstResponder()
        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
    }

    func dismissKeyboard() { textView?.resignFirstResponder() }

    /// "Adicionar comida": teclado aberto numa linha vazia no fim (reaproveita a última se já
    /// estiver vazia), pronta pra escrever.
    func startNewEntry() {
        guard let textView else { return }
        let lines = textView.lineRanges
        if let last = lines.last, last.length > 0 {
            textView.insertLine(after: lines.count - 1, text: "")
        } else {
            focusEnd()
        }
    }

    /// Teclado de volta, com o cursor onde estava.
    func focus() { textView?.becomeFirstResponder() }
}

final class NoteTextView: UITextView {
    static let font = UIFont.systemFont(ofSize: 17)
    static let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    /// Largura da coluna das calorias e o respiro entre ela e o texto.
    static let gutterWidth: CGFloat = 92
    static let gutterSpacing: CGFloat = 12
    static let sideMargin: CGFloat = 24

    var onProgrammaticChange: ((String) -> Void)?
    var placeholder = "" { didSet { placeholderLabel.text = placeholder } }
    var marks: [LineMark] = [] {
        didSet {
            guard marks != oldValue else { return }
            applyLineFonts()
            setNeedsLayout()
        }
    }

    private let placeholderLabel = UILabel()
    private let gutter = UIHostingController(rootView: KcalGutter(rows: []))

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        backgroundColor = .clear
        font = Self.font
        textColor = .label
        typingAttributes = [.font: Self.font, .foregroundColor: UIColor.label]
        textContainerInset = UIEdgeInsets(top: 16, left: Self.sideMargin, bottom: 240,
                                          right: Self.sideMargin + Self.gutterWidth + Self.gutterSpacing)
        self.textContainer.lineFragmentPadding = 0
        alwaysBounceVertical = true
        keyboardDismissMode = .interactive
        // O campo fica entre as barras (o SwiftUI já desconta barras e teclado), então nada de
        // margem automática por cima. Sem cortar nas bordas: o texto continua visível passando por
        // baixo das barras, mas o toque lá em cima e lá embaixo é dos botões, não do texto.
        contentInsetAdjustmentBehavior = .never
        clipsToBounds = false
        autocorrectionType = .default

        placeholderLabel.font = Self.font
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isUserInteractionEnabled = false
        addSubview(placeholderLabel)

        gutter.view.backgroundColor = .clear
        gutter.view.isUserInteractionEnabled = false
        gutter.sizingOptions = []
        addSubview(gutter.view)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não usado") }

    /// TextKit 1 montado na mão: a coluna das calorias lê a posição de cada linha no
    /// NSLayoutManager. (O `init(usingTextLayoutManager:)` pula o init do Swift e crasha.)
    static func make() -> NoteTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        return NoteTextView(frame: .zero, textContainer: container)
    }

    // MARK: Linhas

    /// Faixa de cada linha (sem o "\n"), na ordem.
    var lineRanges: [NSRange] {
        let string = text as NSString
        var ranges: [NSRange] = []
        var start = 0
        while true {
            let newline = string.range(of: "\n", options: [], range: NSRange(location: start, length: string.length - start))
            if newline.location == NSNotFound {
                ranges.append(NSRange(location: start, length: string.length - start))
                return ranges
            }
            ranges.append(NSRange(location: start, length: newline.location - start))
            start = newline.location + 1
        }
    }

    var caretLine: Int {
        let location = selectedRange.location
        return lineRanges.lastIndex { $0.location <= location } ?? 0
    }

    func setTextKeepingCaret(_ newText: String) {
        let selection = selectedRange
        text = newText
        let length = (newText as NSString).length
        selectedRange = NSRange(location: min(selection.location, length), length: 0)
        applyLineFonts()
        setNeedsLayout()
    }

    func replaceLine(_ index: Int, with newText: String, caretAtEnd: Bool) {
        let ranges = lineRanges
        guard ranges.indices.contains(index), markedTextRange == nil else { return }
        let range = ranges[index]
        guard (text as NSString).substring(with: range) != newText || caretAtEnd else { return }
        var selection = selectedRange
        let delta = (newText as NSString).length - range.length
        textStorage.replaceCharacters(in: range, with: NSAttributedString(string: newText, attributes: typingAttributes))
        if caretAtEnd {
            selection = NSRange(location: range.location + (newText as NSString).length, length: 0)
        } else if selection.location > range.location + range.length {
            selection.location += delta
        } else if selection.location > range.location {
            selection = NSRange(location: range.location + min(selection.location - range.location, (newText as NSString).length), length: 0)
        }
        selectedRange = selection
        didChangeProgrammatically()
    }

    func insertLine(after index: Int, text newText: String) {
        let ranges = lineRanges
        let line = ranges[min(max(index, 0), ranges.count - 1)]
        let end = line.location + line.length
        textStorage.replaceCharacters(in: NSRange(location: end, length: 0),
                                      with: NSAttributedString(string: "\n" + newText, attributes: typingAttributes))
        if !isFirstResponder { becomeFirstResponder() }
        selectedRange = NSRange(location: end + 1 + (newText as NSString).length, length: 0)
        didChangeProgrammatically()
    }

    private func didChangeProgrammatically() {
        applyLineFonts()
        setNeedsLayout()
        onProgrammaticChange?(text)
        delegate?.textViewDidChangeSelection?(self)
        scrollRangeToVisible(selectedRange)
    }

    /// Linha que é só título ("Almoço") fica em negrito, como no Notas.
    private func applyLineFonts() {
        guard markedTextRange == nil else { return }
        let ranges = lineRanges
        textStorage.beginEditing()
        for (index, range) in ranges.enumerated() where range.length > 0 {
            let isTitle = marks.indices.contains(index) && marks[index].estimate.isLabel
            textStorage.addAttribute(.font, value: isTitle ? Self.titleFont : Self.font, range: range)
        }
        textStorage.endEditing()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.isHidden = !text.isEmpty
        // Nota vazia não tem caloria do lado: o convite usa a largura toda e quebra linha se
        // precisar, em vez de cortar com reticências.
        let placeholderWidth = bounds.width - textContainerInset.left - Self.sideMargin
        let placeholderHeight = placeholderLabel.sizeThatFits(CGSize(width: placeholderWidth, height: .greatestFiniteMagnitude)).height
        placeholderLabel.frame = CGRect(x: textContainerInset.left, y: textContainerInset.top,
                                        width: placeholderWidth, height: placeholderHeight)

        // Onde cai a primeira linha de cada parágrafo: a caloria se alinha nela.
        layoutManager.ensureLayout(for: textContainer)
        let string = text as NSString
        var rows: [KcalGutter.Row] = []
        for (index, range) in lineRanges.enumerated() {
            let rect: CGRect
            if range.location < string.length {
                let glyph = layoutManager.glyphIndexForCharacter(at: range.location)
                rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else {
                rect = layoutManager.extraLineFragmentRect
            }
            guard index < marks.count else { continue }
            let font = marks[index].estimate.isLabel ? Self.titleFont : Self.font
            rows.append(.init(index: index, baseline: textContainerInset.top + rect.minY + font.ascender,
                              mark: marks[index]))
        }
        gutter.rootView = KcalGutter(rows: rows)
        let height = max(contentSize.height, bounds.height)
        gutter.view.frame = CGRect(x: bounds.width - Self.sideMargin - Self.gutterWidth, y: 0,
                                   width: Self.gutterWidth, height: height)
    }
}

/// A coluna das calorias: um número por linha, na altura da primeira linha do texto dela.
struct KcalGutter: View {
    struct Row: Equatable {
        let index: Int
        let baseline: CGFloat
        let mark: LineMark
    }

    let rows: [Row]
    private static let font = UIFont.systemFont(ofSize: 16, weight: .medium)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            ForEach(rows, id: \.index) { row in
                KcalLabel(mark: row.mark)
                    .offset(y: row.baseline - Self.font.ascender)
            }
        }
    }
}

/// Também usado na vitrine do onboarding (`InputMethodsShowcase`), pra mostrar o rótulo de verdade.
struct KcalLabel: View {
    let mark: LineMark
    private var estimate: LineEstimate { mark.estimate }

    var body: some View {
        HStack(spacing: 4) {
            // Procurando produto de marca no Open Food Facts.
            if mark.isSearching {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                    .transition(.scale.combined(with: .opacity))
            }
            Text("\(kcalLabel)\(Text(kcalLabel.isEmpty || kcalLabel == "?" ? "" : " cal").font(.system(size: 13)))")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(estimate.hasUnknown || estimate.confidence == .estimated ? .tertiary : .secondary)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .animation(Motion.quick, value: mark.isSearching)
        .animation(Motion.quick, value: kcalLabel)
    }

    private var kcalLabel: String {
        if estimate.isLabel || estimate.items.isEmpty { return "" }
        let kcal = Int(estimate.total.kcal.rounded())
        if estimate.items.allSatisfy({ !$0.isRecognized }) { return "?" }
        // "~" = tem chute no número (porção, prato genérico, sabor padrão); "+" = tem item sem número.
        let approximate = estimate.confidence == .estimated ? "~" : ""
        return "\(approximate)\(kcal.formatted())\(estimate.hasUnknown ? "+" : "")"
    }
}
