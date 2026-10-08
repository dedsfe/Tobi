import SwiftUI
import UserNotifications

/// Depois da compra: o confete cai, o Tobi comemora e a tela conta o que a pessoa ganhou, com as datas de verdade.
/// No teste grátis, mostra até quando é de graça e quando chega o aviso. Sem notificação, oferece ligar o aviso
/// ali mesmo, pra promessa da linha do tempo ("Te aviso antes") valer pra todo mundo.
struct PaywallJoy: View {
    let purchase: TobiStore.Purchase
    let onStart: () -> Void

    @State private var store = TobiStore.shared
    @State private var visible = false
    @State private var rows = 0
    @State private var buttonIn = false
    @State private var alert = Alert.checking
    @State private var turnedOn = 0
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private enum Alert { case checking, on, off, blocked }

    /// A primeira cobrança (fim do teste) ou a próxima renovação.
    private var charge: Date {
        purchase.renews
            ?? Calendar.current.date(byAdding: .day, value: TobiPlan.trialDays, to: .now)
            ?? .now
    }

    private var rowCount: Int { purchase.trial ? 3 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Agora somos")
                Text("nós dois")
                    .foregroundStyle(.indigo)
            }
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .reveal(visible, order: 0)

            Text(purchase.trial ? "Seu teste começou. Tá tudo liberado." : "Sua assinatura tá ativa. Tá tudo liberado.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .reveal(visible, order: 1)

            VStack(alignment: .leading, spacing: 18) {
                if purchase.trial {
                    JoyRow(symbol: "gift.fill",
                           title: "Grátis até \(Self.day(charge))",
                           detail: "Depois, \(store.displayPrice(purchase.plan)) por \(purchase.plan.period)",
                           isShown: rows >= 1)
                    reminderRow
                        .reveal(rows >= 2, order: 0)
                    JoyRow(symbol: "checkmark.shield.fill",
                           title: "Sem cobrança hoje",
                           detail: "Cancela quando quiser, nos Ajustes do iPhone",
                           isShown: rows >= 3)
                } else {
                    JoyRow(symbol: "checkmark.seal.fill",
                           title: "Plano \(purchase.plan.name.lowercased()) ativo",
                           detail: "Renova \(Self.onDay(charge))",
                           isShown: rows >= 1)
                    JoyRow(symbol: "checkmark.shield.fill",
                           title: "Cancela quando quiser",
                           detail: "Nos Ajustes do iPhone, até 24 horas antes",
                           isShown: rows >= 2)
                }
            }
            .padding(.top, 28)

            Spacer(minLength: 16)

            PaywallButton(title: "Começar meu dia", action: onStart)
                .reveal(buttonIn, order: 0)
                .allowsHitTesting(buttonIn)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sensoryFeedback(.selection, trigger: rows)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: buttonIn)
        .sensoryFeedback(.success, trigger: turnedOn)
        .task { await choreograph() }
        .onChange(of: scenePhase) { _, phase in
            // Voltou dos Ajustes: se ligou as notificações lá, o aviso já fica agendado.
            if phase == .active, alert == .blocked { Task { await checkAlert(scheduleIfOn: true) } }
        }
    }

    // MARK: Aviso

    /// "Te aviso na quinta" com a notificação ligada; sem ela, o mesmo lugar oferece ligar.
    @ViewBuilder
    private var reminderRow: some View {
        let isOn = alert == .on || alert == .checking
        HStack(alignment: .center, spacing: 14) {
            JoyRow(symbol: isOn ? "bell.fill" : "bell.slash.fill",
                   title: isOn ? "Te aviso \(Self.onDay(TobiStore.reminderDate(beforeCharge: charge)))" : "Aviso desligado",
                   detail: isOn ? "Um dia antes da cobrança" : "Liga pra saber antes da cobrança",
                   isShown: true)
            if !isOn {
                Button("Ativar", action: turnOn)
                    .font(.system(size: 15, weight: .semibold))
                    .buttonStyle(.glass)
                    .tint(.indigo)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(Motion.surface, value: isOn)
    }

    private func turnOn() {
        Task {
            if alert == .blocked {
                // Já disse não pro sistema: só dá pra ligar nos Ajustes.
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                return
            }
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                await TobiStore.remindBeforeCharge(on: charge)
                alert = .on
                turnedOn += 1
            } else {
                alert = .blocked
            }
        }
    }

    private func checkAlert(scheduleIfOn: Bool = false) async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let next: Alert = switch status {
        case .authorized, .provisional, .ephemeral: .on
        case .denied: .blocked
        default: .off
        }
        if scheduleIfOn, next == .on, alert != .on {
            await TobiStore.remindBeforeCharge(on: charge)
            turnedOn += 1
        }
        alert = next
    }

    // MARK: Coreografia

    private func choreograph() async {
        if purchase.trial { await checkAlert() }
        // A oferta sai e o confete sobe antes do título chegar.
        try? await Task.sleep(for: .milliseconds(450))
        visible = true
        try? await Task.sleep(for: .milliseconds(380))
        for index in 1...rowCount {
            withAnimation(Motion.surface) { rows = index }
            try? await Task.sleep(for: .milliseconds(160))
        }
        try? await Task.sleep(for: .milliseconds(240))
        withAnimation(Motion.surface) { buttonIn = true }
    }

    // MARK: Datas

    /// "sexta, 10 de out.", com o ano quando não é este.
    static func day(_ date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.wide)).replacingOccurrences(of: "-feira", with: "")
        let sameYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        let day = sameYear ? date.formatted(.dateTime.day().month(.abbreviated))
            : date.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(weekday), \(day)"
    }

    /// "amanhã", "na quinta, 9 de out.", "no sábado, 11 de out.".
    static func onDay(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "hoje" }
        if Calendar.current.isDateInTomorrow(date) { return "amanhã" }
        let weekday = Calendar.current.component(.weekday, from: date)
        // Domingo e sábado são "o"; os outros dias, "a".
        return "\(weekday == 1 || weekday == 7 ? "no" : "na") \(day(date))"
    }
}

/// Uma coisa que a pessoa ganhou. Não é clicável, então não tem cara de cartão.
private struct JoyRow: View {
    let symbol: String
    let title: String
    let detail: String
    let isShown: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.indigo)
                .frame(width: 28)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: isShown)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.opacity)
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reveal(isShown, order: 0)
    }
}
