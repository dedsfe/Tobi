import UIKit

/// Os atalhos de segurar o ícone do Tobi na tela de início.
@MainActor
enum QuickActions {
    /// Abre direto a tela de escrever avaliação na App Store.
    static let review = URL(string: "https://apps.apple.com/app/id6820744889?action=write-review")!
    static let contact = URL(string: "mailto:contato@oracaodiaria.com?subject=Tobi")!

    /// Atalho tocado com o app fechado: espera o app abrir pra executar.
    static var pending: UIApplicationShortcutItem?

    static func install() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: "review", localizedTitle: "Avaliar o Tobi",
                                      localizedSubtitle: "Leva 10 segundos e ajuda muito",
                                      icon: UIApplicationShortcutIcon(systemImageName: "star.fill")),
            UIApplicationShortcutItem(type: "contact", localizedTitle: "Falar com a gente",
                                      localizedSubtitle: "Dúvida, ideia ou problema",
                                      icon: UIApplicationShortcutIcon(systemImageName: "envelope.fill")),
        ]
    }

    static func perform(_ item: UIApplicationShortcutItem) {
        switch item.type {
        case "review": UIApplication.shared.open(review)
        case "contact": UIApplication.shared.open(contact)
        default: break
        }
    }

    static func performPending() {
        guard let item = pending else { return }
        pending = nil
        perform(item)
    }
}

final class TobiAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        QuickActions.install()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        QuickActions.pending = options.shortcutItem
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

/// Atalho tocado com o app já aberto em segundo plano.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        QuickActions.perform(shortcutItem)
        return true
    }
}
