import Foundation
import StoreKit

/// Eventos anônimos pro Supabase (tabela `analytics_events`): mede onde as pessoas param no onboarding.
/// Sem login e sem resposta da pessoa (peso, idade...), só qual tela apareceu e o que foi tocado.
/// Fire-and-forget: nunca segura a tela nem reclama se a rede cair.
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

    static func stepViewed(_ step: OnboardingStep) {
        track("onboarding_step_viewed", step: step)
    }

    static func track(_ event: String, step: OnboardingStep? = nil, properties: [String: String] = [:]) {
        var body: [String: Any] = [
            "anon_id": anonID,
            "event": event,
            "properties": properties,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
        ]
        if let step {
            body["step"] = step.analyticsName
            body["step_index"] = step.rawValue
        }
        #if DEBUG
        print("[Analytics] \(event) \(step?.analyticsName ?? "") \(properties)")
        #endif
        guard let base = try? JSONSerialization.data(withJSONObject: body) else { return }
        Task.detached(priority: .utility) {
            await send(base)
        }
    }

    private static func send(_ base: Data) async {
        guard var body = try? JSONSerialization.jsonObject(with: base) as? [String: Any] else { return }
        body["build_env"] = await buildEnv()
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let response = try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse
        #if DEBUG
        if response?.statusCode != 201 { print("[Analytics] falhou: \(response?.statusCode ?? 0)") }
        #endif
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
