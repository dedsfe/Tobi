import SwiftUI
import UIKit

/// Campo de uma linha que se comporta como o app Notas: quebra quando o texto é longo,
/// enter divide a linha no cursor e apagar no começo junta com a linha de cima.
/// (O TextField do SwiftUI não avisa o apagar numa linha vazia, por isso o UITextView.)
struct LineEditor: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let isFocused: Bool
    /// Nenhuma linha em foco: aí sim fecha o teclado. Entre linhas, o foco só passa de uma pra
    /// outra, sem fechar e abrir o teclado.
    let dismissKeyboard: Bool
    /// Onde pôr o cursor quando o foco chega por código (nil = fim da linha).
    let cursor: Int?
    var onFocusChange: (Bool) -> Void
    /// Enter: o texto antes do cursor fica, o depois vai pra linha nova.
    var onReturn: (_ before: String, _ after: String) -> Void
    /// Apagar com o cursor no começo da linha.
    var onDeleteAtStart: () -> Void

    func makeUIView(context: Context) -> NoteTextView {
        let view = NoteTextView()
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textColor = .label
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.onDeleteAtStart = { context.coordinator.parent.onDeleteAtStart() }
        return view
    }

    func updateUIView(_ view: NoteTextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text { view.text = text }
        if view.font != font { view.font = font }

        view.wantsFocus = isFocused
        if isFocused, !view.isFirstResponder {
            view.pendingCursor = cursor
            if view.window != nil { view.takeFocus() }
        } else if dismissKeyboard, view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NoteTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: max(height, font.lineHeight))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LineEditor

        init(parent: LineEditor) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
            // Só o enter digitado; texto colado com várias linhas passa e o DayView divide.
            guard replacementText == "\n", let current = textView.text as NSString? else { return true }
            parent.onReturn(current.substring(to: range.location), current.substring(from: range.location + range.length))
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        // Avisam depois do ciclo atual: o foco pode mudar no meio de uma atualização da tela.
        func textViewDidBeginEditing(_ textView: UITextView) {
            Task { @MainActor in self.parent.onFocusChange(true) }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            Task { @MainActor in self.parent.onFocusChange(false) }
        }
    }
}

final class NoteTextView: UITextView {
    var onDeleteAtStart: (() -> Void)?
    /// Deve estar em foco. Linha recém-criada ainda não está na tela: pega o foco quando entrar.
    var wantsFocus = false
    var pendingCursor: Int?

    func takeFocus() {
        guard becomeFirstResponder() else { return }
        let offset = min(pendingCursor ?? text.utf16.count, text.utf16.count)
        selectedRange = NSRange(location: offset, length: 0)
        pendingCursor = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if wantsFocus, window != nil, !isFirstResponder { takeFocus() }
    }

    override func deleteBackward() {
        if selectedRange == NSRange(location: 0, length: 0) {
            onDeleteAtStart?()
            return
        }
        super.deleteBackward()
    }
}
