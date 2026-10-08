import SwiftUI

/// Cartão pequeno tipo "toasterzinho", aberto pelo "?" da coluna das calorias: diz de forma
/// humilde e direta o que o Tobi não entendeu e por quê.
struct UnknownHelpCard: View {
    struct Problem: Identifiable {
        let id: Int
        /// O trecho como a pessoa escreveu ("Xis Salada").
        let written: String
        let help: FoodParser.Help
    }

    let problems: [Problem]
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                if let problem = problems.first {
                    Text("Não entendi “\(problem.written)”")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(Self.shortReason(for: problem.help))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 270)
        .helpSurface(cornerRadius: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unknownHelpCard")
    }

    /// Explicação resumida e humilde, direta ao ponto.
    static func shortReason(for help: FoodParser.Help) -> String {
        if let fix = help.typoFix {
            return "Parece digitação de “\(fix.name)”"
        }
        if !help.knownWords.isEmpty, !help.unknownWords.isEmpty {
            return "Não conheço “\(help.unknownWords.joined(separator: " "))”"
        }
        return "Alimento não encontrado na base"
    }

    /// O porquê completo (mantido para testes e inspeção).
    static func reasons(for help: FoodParser.Help) -> [String] {
        help.reasons
    }
}

/// Sugestões que aparecem em cima ou embaixo do trecho sublinhado: o que a pessoa pode ter querido dizer.
/// Pequeno, elegante e com opções clicáveis que substituem a palavra.
struct SuggestionBubble: View {
    let suggestions: [Food]
    let isAsking: Bool
    var message: String?
    var onPick: (Food) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if suggestions.isEmpty && !isAsking {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Nenhuma sugestão na base")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                ForEach(Array(suggestions.prefix(4).enumerated()), id: \.element.name) { index, food in
                    Button { onPick(food) } label: {
                        HStack(spacing: 8) {
                            Text(food.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.turn.down.left")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary.opacity(0.4))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggestion-\(index)")
                    .transition(.emerge(from: .top))

                    if index < min(suggestions.count, 4) - 1 || isAsking {
                        Divider().padding(.leading, 12)
                    }
                }
            }

            if isAsking {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .symbolEffect(.pulse)
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                    Text("Entendendo com IA...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .transition(.opacity)
            } else if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
        }
        .frame(width: 210, alignment: .leading)
        .helpSurface(cornerRadius: 14)
        .animation(Motion.quick, value: suggestions.map(\.name))
        .animation(Motion.quick, value: isAsking)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggestionBubble")
    }
}

private extension View {
    /// Superfície elegante do app: leve, com borda sutil e sombra suave.
    func helpSurface(cornerRadius: CGFloat = 16) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}
