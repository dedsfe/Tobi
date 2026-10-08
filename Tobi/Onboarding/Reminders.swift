import Foundation
import UserNotifications

/// Lembretes diários de registrar as refeições. A tela de notificações do onboarding mostra
/// exatamente estes textos antes de pedir a permissão.
enum Reminders {
    struct Reminder: Identifiable {
        let id: String
        let hour: Int
        let minute: Int
        let message: String

        /// "9:00", pra prévia.
        var time: String { String(format: "%d:%02d", hour, minute) }
    }

    static let daily = [
        Reminder(id: "reminder.breakfast", hour: 9, minute: 0, message: "Bom dia! O que teve no café? Escreve rapidinho ☕️"),
        Reminder(id: "reminder.lunch", hour: 12, minute: 30, message: "Já almoçou? Anota antes que esqueça 🍽️"),
        Reminder(id: "reminder.dinner", hour: 20, minute: 0, message: "Como foi o dia? Registra o jantar e fecha a conta 🌙"),
    ]

    /// Pede a permissão e, se der, agenda os três lembretes todo dia. Devolve se ficou ligado.
    @discardableResult
    static func enable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        UserDefaults.standard.set(granted, forKey: "remindersEnabled")
        guard granted else { return false }

        center.removePendingNotificationRequests(withIdentifiers: daily.map(\.id))
        for reminder in daily {
            let content = UNMutableNotificationContent()
            content.title = "Tobi"
            content.body = reminder.message
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: reminder.hour, minute: reminder.minute), repeats: true)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
        return true
    }
}
