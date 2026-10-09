import Foundation
import PostHog
import StoreKit

/// Eventos anônimos pro Supabase (tabela `analytics_events`) e pro PostHog: mede onde as pessoas param.
/// Sem login e sem resposta da pessoa (peso, idade...), só qual tela apareceu e o que foi tocado.
/// Nunca segura a tela: sem rede, o evento espera no aparelho e vai junto com o próximo.
enum Analytics {
    private static let endpoint = URL(string: "https://wluqzlfkclrjocdjlmeu.supabase.co/rest/v1/analytics_events")!
    /// Chave publicável: feita pra ir dentro do app, só consegue gravar evento (RLS).
    private static let publishableKey = "sb_publishable_cryhZudzqSF0tlHwCTKQAg_v0OXxHic"

    /// Id do aparelho, criado no primeiro evento. Liga as telas da mesma pessoa sem saber quem ela é.
    static var anonID: String {
        let key = "analytics.anonID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }

    /// Chave do PostHog: só grava evento, feita pra ir dentro do app.
    private static let postHogKey = "phc_sv9Nn5goGFHoZsRouMrBdSHqFn5o7BWHoxhhKtTMChvK"

    /// Liga o PostHog na abertura: eventos, abrir/fechar o app e a gravação da sessão.
    /// Na gravação, tudo que é digitado aparece coberto (as refeições nunca vão).
    static func start() {
        let config = PostHogConfig(projectToken: postHogKey, host: "https://us.i.posthog.com")
        config.captureApplicationLifecycleEvents = true
        // As telas do SwiftUI chegam com nomes internos sem sentido; as do onboarding já vão pelo `stepViewed`.
        config.captureScreenViews = false
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = false
        PostHogSDK.shared.setup(config)
        // Mesmo id do Supabase: dá pra cruzar as duas bases.
        PostHogSDK.shared.identify(anonID)
        Task.detached(priority: .utility) {
            PostHogSDK.shared.register(["build_env": await buildEnv()])
        }
    }

    static func stepViewed(_ step: OnboardingStep) {
        track("onboarding_step_viewed", step: step)
    }

    static func track(_ event: String, step: OnboardingStep? = nil, properties: [String: String] = [:]) {
        var body: [String: Any] = [
            "anon_id": anonID,
            "event": event,
            "properties": properties,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            // A hora em que aconteceu, não a hora em que a rede voltou.
            "created_at": Date.now.formatted(.iso8601),
        ]
        if let step {
            body["step"] = step.analyticsName
            body["step_index"] = step.rawValue
        }
        #if DEBUG
        print("[Analytics] \(event) \(step?.analyticsName ?? "") \(properties)")
        #endif
        var postHogProperties: [String: Any] = properties
        if let step {
            postHogProperties["step"] = step.analyticsName
            postHogProperties["step_index"] = step.rawValue
        }
        PostHogSDK.shared.capture(event, properties: postHogProperties)
        guard let event = try? JSONSerialization.data(withJSONObject: body) else { return }
        Task.detached(priority: .utility) {
            await AnalyticsOutbox.shared.add(event)
        }
    }

    enum Delivery { case sent, retryLater, dropped }

    static func post(_ event: Data) async -> Delivery {
        guard var body = try? JSONSerialization.jsonObject(with: event) as? [String: Any] else { return .dropped }
        body["build_env"] = await buildEnv()
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let response = try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse else {
            return .retryLater
        }
        #if DEBUG
        if response.statusCode != 201 { print("[Analytics] falhou: \(response.statusCode)") }
        #endif
        switch response.statusCode {
        case 200..<300: return .sent
        // Evento torto nunca vai passar: descarta pra não travar a fila.
        case 400, 409, 413, 422: return .dropped
        default: return .retryLater
        }
    }

    /// Separa teste de gente de verdade: "debug" (Xcode), "testflight" ou "appstore".
    private static func buildEnv() async -> String {
        #if DEBUG
        return "debug"
        #else
        guard case .verified(let app)? = try? await AppTransaction.shared else { return "appstore" }
        switch app.environment {
        case .sandbox: return "testflight"
        case .xcode: return "debug"
        default: return "appstore"
        }
        #endif
    }
}

/// Fila dos eventos que ainda não chegaram no Supabase, guardada num arquivo.
/// Todo evento novo tenta mandar a fila inteira, na ordem.
private actor AnalyticsOutbox {
    static let shared = AnalyticsOutbox()
    /// Teto pra um aparelho sem rede por semanas não encher o disco.
    private static let limit = 500
    private let file = URL.applicationSupportDirectory.appending(path: "analytics-outbox.json")
    private lazy var pending: [Data] = (try? JSONDecoder().decode([Data].self, from: Data(contentsOf: file))) ?? []
    private var flushing = false

    func add(_ event: Data) async {
        pending.append(event)
        if pending.count > Self.limit { pending.removeFirst(pending.count - Self.limit) }
        save()
        await flush()
    }

    private func flush() async {
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        while let next = pending.first {
            if await Analytics.post(next) == .retryLater { return }
            if let index = pending.firstIndex(of: next) { pending.remove(at: index) }
            save()
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(pending).write(to: file, options: .atomic)
    }
}

extension OnboardingStep {
    /// Nome fixo no banco: renomear o case não quebra o histórico do funil.
    var analyticsName: String {
        switch self {
        case .welcome: "welcome"
        case .sex: "sex"
        case .birthday: "birthday"
        case .height: "height"
        case .objective: "objective"
        case .weight: "weight"
        case .activity: "activity"
        case .pace: "pace"
        case .goals: "goals"
        case .firstMeal: "first_meal"
        case .inputs: "inputs"
        case .celebration: "celebration"
        case .notifications: "notifications"
        case .paywall: "paywall"
        }
    }
}
