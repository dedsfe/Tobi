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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let suggestions: [Food]
    let isAsking: Bool
    var message: String?
    var onPick: (Food) -> Void
    var requestState: FoodRequestState
    var onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if requestState == .sent {
                FoodRequestConfirmation()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
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

                VStack(alignment: .leading, spacing: 4) {
                    switch requestState {
                    case .queued:
                        Text("Pedido salvo")
                            .font(.system(size: 13, weight: .medium))
                            .accessibilityIdentifier("food-request-status")
                        Text("Enviaremos quando houver conexão.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    case .idle, .sending, .failed:
                        if requestState == .failed {
                            Text("Não foi possível salvar o pedido. Tente de novo.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Button(action: onRequest) {
                            HStack(spacing: 8) {
                                if requestState == .sending { ProgressView().controlSize(.mini) }
                                Text(requestState == .sending ? "Enviando pedido..." : "Pedir para adicionar")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(requestState == .sending)
                        .accessibilityIdentifier("request-food")
                    case .sent:
                        EmptyView()
                    }
                }
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 210, alignment: .leading)
        .helpSurface(cornerRadius: 14)
        .animation(reduceMotion ? nil : Motion.quick, value: suggestions.map(\.name))
        .animation(reduceMotion ? nil : Motion.quick, value: isAsking)
        .animation(reduceMotion ? nil : Motion.quick, value: requestState)
        .sensoryFeedback(.success, trigger: requestState == .sent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggestionBubble")
    }
}

/// O texto já nasce legível. Só o símbolo faz o traço e o pequeno impulso de confirmação.
private struct FoodRequestConfirmation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private struct Frame {
        var stroke: CGFloat = 1
        var scale: CGFloat = 1
    }

    private let green = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.41, green: 0.84, blue: 0.56, alpha: 1)
            : UIColor(red: 0.09, green: 0.45, blue: 0.25, alpha: 1)
    })

    var body: some View {
        HStack(spacing: 9) {
            if reduceMotion {
                symbol(Frame())
            } else {
                Color.clear
                    .frame(width: 24, height: 24)
                    .keyframeAnimator(initialValue: Frame(), trigger: appeared) { _, frame in
                        symbol(frame)
                    } keyframes: { _ in
                        KeyframeTrack(\.stroke) {
                            MoveKeyframe(0)
                            CubicKeyframe(1, duration: Motion.foodRequestDrawDuration)
                        }
                        KeyframeTrack(\.scale) {
                            MoveKeyframe(0.84)
                            SpringKeyframe(1.10, duration: Motion.foodRequestPopDuration)
                            CubicKeyframe(1, duration: Motion.foodRequestSettleDuration)
                        }
                    }
            }
            Text("Pedido enviado")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityIdentifier("food-request-status")
        }
        .foregroundStyle(green)
        .onAppear {
            appeared = true
            UIAccessibility.post(notification: .announcement, argument: "Pedido enviado")
        }
    }

    nonisolated private func symbol(_ frame: Frame) -> some View {
        ZStack {
            Circle().inset(by: 2).stroke(lineWidth: 1.5)
            Checkmark().trim(from: 0, to: frame.stroke)
                .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 24)
        .scaleEffect(frame.scale)
        .accessibilityHidden(true)
    }

    private struct Checkmark: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.51))
                path.addLine(to: CGPoint(x: rect.width * 0.44, y: rect.height * 0.66))
                path.addLine(to: CGPoint(x: rect.width * 0.73, y: rect.height * 0.36))
            }
        }
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
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        }
    }
}
