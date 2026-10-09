import Foundation

/// Quando perguntar "O que você está achando do Tobi?": nos primeiros dias (o dia grátis e o teste),
/// logo depois de a pessoa anotar comida, que é quando o app acabou de ser útil.
@MainActor @Observable
final class FeedbackPrompt {
    static let shared = FeedbackPrompt()

    var isShowing = false

    /// Já usou um pouco: pelo menos 3 horas depois da primeira anotação, e só até o 4º dia.
    private static let earliest: TimeInterval = 3 * 3600
    private static let latest: TimeInterval = 4 * 24 * 3600
    /// Quem fechou sem responder vê de novo uma vez, no dia seguinte.
    private static let maxShows = 2
    private static let gap: TimeInterval = 20 * 3600

    private let defaults = UserDefaults.standard

    private init() {}

    /// Chamado quando o teclado fecha no dia de hoje, com quantas linhas o Tobi reconheceu.
    func userFinishedLogging(recognizedLines: Int) {
        guard recognizedLines >= 2, !defaults.bool(forKey: "feedback.answered") else { return }
        let now = Date.now
        guard let firstUse = defaults.object(forKey: "feedback.firstUse") as? Date else {
            defaults.set(now, forKey: "feedback.firstUse")
            return
        }
        let elapsed = now.timeIntervalSince(firstUse)
        guard elapsed >= Self.earliest, elapsed <= Self.latest,
              defaults.integer(forKey: "feedback.shows") < Self.maxShows else { return }
        if let last = defaults.object(forKey: "feedback.lastShown") as? Date, now.timeIntervalSince(last) < Self.gap {
            return
        }
        defaults.set(defaults.integer(forKey: "feedback.shows") + 1, forKey: "feedback.shows")
        defaults.set(now, forKey: "feedback.lastShown")
        show()
    }

    func show(after delay: Double = 0.5) {
        Task {
            // Deixa o teclado e a barra terminarem de descer antes de subir o modal.
            try? await Task.sleep(for: .seconds(delay))
            isShowing = true
            Analytics.track("feedback_prompt_shown")
        }
    }

    /// Respondeu (gostou ou mandou o que melhorar): nunca mais pergunta.
    func markAnswered() {
        defaults.set(true, forKey: "feedback.answered")
    }
}

/// Manda a opinião pra tabela `app_feedback` do Supabase. Sem rede, guarda e tenta na próxima abertura.
enum FeedbackClient {
    private static let endpoint = URL(string: "https://wluqzlfkclrjocdjlmeu.supabase.co/rest/v1/app_feedback")!
    private static let publishableKey = "sb_publishable_cryhZudzqSF0tlHwCTKQAg_v0OXxHic"
    private static let pendingKey = "feedback.pending"

    enum Sentiment: String { case liked = "gostou", disliked = "nao_gostou" }

    static func send(_ sentiment: Sentiment, message: String? = nil, canContact: Bool = false, contact: String? = nil) {
        var body: [String: Any] = [
            "anon_id": Analytics.anonID,
            "sentiment": sentiment.rawValue,
            "can_contact": canContact,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
        ]
        if let message, !message.isEmpty { body["message"] = String(message.prefix(2000)) }
        if canContact, let contact, !contact.isEmpty { body["contact"] = String(contact.prefix(200)) }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        Task.detached(priority: .utility) {
            if await !post(data) { UserDefaults.standard.set(data, forKey: pendingKey) }
        }
    }

    /// O feedback que ficou sem rede da última vez.
    static func retryPending() {
        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return }
        Task.detached(priority: .utility) {
            if await post(data) { UserDefaults.standard.removeObject(forKey: pendingKey) }
        }
    }

    private static func post(_ data: Data) async -> Bool {
        guard var body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return true }
        body["build_env"] = await Analytics.buildEnv()
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let response = try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse else { return false }
        // Erro de formato nunca vai passar: descarta em vez de tentar pra sempre.
        return (200..<300).contains(response.statusCode) || (400..<500).contains(response.statusCode)
    }
}
