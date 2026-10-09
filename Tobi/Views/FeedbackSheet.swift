import PostHog
import StoreKit
import SwiftUI

/// "O que você está achando do Tobi?". Gostou: a janelinha de estrelas da App Store.
/// Não gostou: conta o que melhorar (vai pro Supabase) e diz se topa ser chamado.
struct FeedbackSheet: View {
    private enum Step { case ask, improve, thanks }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.ask
    @State private var detent = PresentationDetent.height(Self.askHeight)
    @State private var message = ""
    @State private var canContact = false
    @State private var contact = ""
    @State private var modelReady = false
    @FocusState private var messageFocused: Bool

    private static let askHeight: CGFloat = 470

    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .ask: ask.transition(.emerge)
            case .improve: improve.transition(.emerge)
            case .thanks: thanks.transition(.emerge)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(Self.askHeight), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: step)
        .sensoryFeedback(.selection, trigger: canContact)
    }

    // MARK: Pergunta

    private var ask: some View {
        VStack(spacing: 0) {
            tobi(height: 150)
                .padding(.top, 16)
            Text("O que você está achando do Tobi?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Text("Sua resposta ajuda a gente a deixar o app do seu jeito.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            VStack(spacing: 10) {
                Button(action: liked) {
                    Label("Tô gostando muito", systemImage: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(.indigo)
                Button(action: disliked) {
                    Text("Podia ser melhor")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            }
            .padding(.top, 24)
            Button("Agora não", action: notNow)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 14)
        }
    }

    // MARK: O que melhorar

    private var improve: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("O que podemos melhorar?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding(.top, 28)
            Text("Conta sem filtro. A gente lê cada mensagem.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            TextEditor(text: $message)
                .font(.system(size: 17))
                .scrollContentBackground(.hidden)
                .focused($messageFocused)
                .frame(height: 130)
                .padding(12)
                .overlay(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("O que faltou, o que incomodou, o que você mudaria")
                            .font(.system(size: 17))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .postHogMask()
                .padding(.top, 18)

            Toggle(isOn: $canContact.animation(Motion.surface)) {
                Text("Pode me chamar pra conversar sobre isso")
                    .font(.system(size: 16, weight: .medium))
            }
            .toggleStyle(CheckToggleStyle())
            .padding(.top, 16)

            if canContact {
                TextField("Seu e-mail ou WhatsApp", text: $contact)
                    .font(.system(size: 17))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    .postHogMask()
                    .padding(.top, 12)
                    .transition(.emerge)
            }

            Button(action: send) {
                Text("Enviar")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(.indigo)
            .disabled(trimmedMessage.isEmpty)
            .padding(.top, 20)
        }
    }

    // MARK: Obrigado

    private var thanks: some View {
        VStack(spacing: 0) {
            tobi(height: 170)
                .padding(.top, 24)
            Text("Valeu demais!")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.top, 8)
            Text(canContact && !contact.isEmpty
                 ? "Já recebemos. Se precisar, a gente te chama."
                 : "Já recebemos. Isso vai virar melhoria no Tobi.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .sensoryFeedback(.success, trigger: step)
    }

    /// O Tobi 3D se mexendo; o rostinho fica no lugar enquanto o modelo carrega ou se falhar.
    private func tobi(height: CGFloat) -> some View {
        ZStack {
            Image(uiImage: UIImage(named: "tobi-head") ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: height * 0.7)
                .opacity(modelReady ? 0 : 1)
            TobiFaceView(isPlaying: true, blinkRequest: 0, lookRequest: 0, isActive: true,
                         reduceMotion: reduceMotion,
                         onReady: { withAnimation(Motion.surface) { modelReady = true } })
                .opacity(modelReady ? 1 : 0)
        }
        .frame(height: height)
    }

    // MARK: Ações

    private func liked() {
        Analytics.track("feedback_liked")
        FeedbackClient.send(.liked)
        FeedbackPrompt.shared.markAnswered()
        dismiss()
        Task {
            // A janelinha de estrelas sobe depois que o modal desce.
            try? await Task.sleep(for: .seconds(0.5))
            requestReview()
        }
    }

    private func disliked() {
        Analytics.track("feedback_disliked")
        withAnimation(Motion.surface) {
            detent = .large
            step = .improve
        }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            messageFocused = true
        }
    }

    private func notNow() {
        Analytics.track("feedback_dismissed")
        dismiss()
    }

    private func send() {
        guard !trimmedMessage.isEmpty else { return }
        let contactText = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        FeedbackClient.send(.disliked, message: trimmedMessage, canContact: canContact, contact: contactText)
        Analytics.track("feedback_sent", properties: ["pode_contatar": canContact && !contactText.isEmpty ? "sim" : "nao"])
        FeedbackPrompt.shared.markAnswered()
        messageFocused = false
        withAnimation(Motion.surface) {
            detent = .height(Self.askHeight)
            step = .thanks
        }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            dismiss()
        }
    }
}

/// Caixinha de marcar: círculo vazio ou com o check, em índigo.
private struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(configuration.isOn ? AnyShapeStyle(.indigo) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                configuration.label
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
