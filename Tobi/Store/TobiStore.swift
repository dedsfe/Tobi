import Foundation
import RevenueCat
import StoreKit
import UserNotifications

/// Os planos do Tobi. IDs e preços de reserva vivem só aqui (e no Tobi.storekit, pra testar no Xcode).
enum TobiPlan: String, CaseIterable, Identifiable, Sendable {
    case annual = "com.andrefelipe.tobi.annual"
    case weekly = "com.andrefelipe.tobi.weekly"

    var id: String { rawValue }

    /// Teste grátis dos dois planos.
    static let trialDays = 3

    /// Preço mostrado enquanto a App Store não responde. Mudou aqui, muda no Tobi.storekit também.
    var fallbackPrice: Decimal {
        switch self {
        case .annual: Decimal(string: "99.90")!
        case .weekly: Decimal(string: "12.90")!
        }
    }

    var name: String {
        switch self {
        case .annual: "Anual"
        case .weekly: "Semanal"
        }
    }

    /// "por ano", "por semana".
    var period: String {
        switch self {
        case .annual: "ano"
        case .weekly: "semana"
        }
    }

    var weeks: Decimal {
        switch self {
        case .annual: 52
        case .weekly: 1
        }
    }
}

/// A loja do Tobi em StoreKit 2: carrega os planos, compra, restaura e guarda as 24 horas de cortesia.
@MainActor @Observable
final class TobiStore {
    static let shared = TobiStore()

    private(set) var products: [TobiPlan: Product] = [:]
    /// Quem já usou o teste grátis não ganha outro. Enquanto a loja não responde, conta que ganha.
    private(set) var trialEligible = true
    /// Tem plano ativo. nil enquanto ainda não conferiu, pra não travar ninguém na abertura.
    private(set) var subscribed: Bool?
    /// As 24 horas de cortesia ainda valem.
    private(set) var freePassActive = TobiStore.freePassUntil.map { $0 > .now } ?? false
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var passWatch: Task<Void, Never>?

    /// Pode usar o app: assinou ou está nas 24 horas.
    var hasAccess: Bool { subscribed != false || freePassActive }

    /// O que a compra deu, pra tela de alegria contar com as datas de verdade.
    struct Purchase: Equatable {
        let plan: TobiPlan
        /// Começou o teste grátis, sem cobrança hoje.
        let trial: Bool
        /// Fim do teste (a primeira cobrança) ou a próxima renovação.
        let renews: Date?
    }

    enum Outcome { case purchased(Purchase), cancelled, pending }
    enum Failure: Error { case unavailable, unverified }

    /// Chave pública do RevenueCat (app da App Store). É feita pra ficar dentro do app.
    private static let revenueCatKey = "appl_kKDCrvHhYDtuBFpojWZOcwXvODV"

    private init() {
        // O RevenueCat só observa: a compra é feita aqui em StoreKit 2 e ele registra pro painel e pros anúncios.
        Purchases.logLevel = .warn
        Purchases.configure(with: Configuration.Builder(withAPIKey: Self.revenueCatKey)
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
            .build())
        // Renovações e compras aprovadas fora do app chegam por aqui.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshAccess()
            }
        }
        watchFreePass()
    }

    /// Confere na App Store se a conta tem plano ativo.
    func refreshAccess() async {
        subscribed = await hasActiveSubscription()
    }

    func load() async {
        guard products.isEmpty,
              let loaded = try? await Product.products(for: TobiPlan.allCases.map(\.rawValue)) else { return }
        for product in loaded {
            if let plan = TobiPlan(rawValue: product.id) { products[plan] = product }
        }
        if let subscription = products[.annual]?.subscription {
            trialEligible = await subscription.isEligibleForIntroOffer
        }
    }

    // MARK: Preços

    func price(_ plan: TobiPlan) -> Decimal {
        products[plan]?.price ?? plan.fallbackPrice
    }

    /// "R$ 99,90".
    func displayPrice(_ plan: TobiPlan) -> String {
        format(price(plan), plan)
    }

    /// Quanto o plano sai por semana: "R$ 1,92".
    func weeklyPrice(_ plan: TobiPlan) -> String {
        format(price(plan) / plan.weeks, plan)
    }

    /// Quanto o anual economiza contra pagar semana a semana, em %.
    var annualSavings: Int {
        let ratio = NSDecimalNumber(decimal: price(.annual) / TobiPlan.annual.weeks / price(.weekly)).doubleValue
        return Int(((1 - ratio) * 100).rounded(.down))
    }

    private func format(_ value: Decimal, _ plan: TobiPlan) -> String {
        if let product = products[plan] { return value.formatted(product.priceFormatStyle) }
        return value.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }

    // MARK: Compra

    func purchase(_ plan: TobiPlan) async throws -> Outcome {
        #if DEBUG
        // No aparelho sem o Xcode a App Store não tem os planos: finge a compra pra dar pra ver a tela de alegria.
        if products[plan] == nil {
            try? await Task.sleep(for: .seconds(0.8))
            subscribed = true
            let trial = trialEligible
            let renews = Calendar.current.date(byAdding: trial ? .day : plan == .annual ? .year : .weekOfYear,
                                               value: trial ? TobiPlan.trialDays : 1, to: .now)
            if trial, let renews { await Self.remindBeforeCharge(on: renews) }
            return .purchased(Purchase(plan: plan, trial: trial, renews: renews))
        }
        #endif
        guard let product = products[plan] else { throw Failure.unavailable }
        let result = try await product.purchase()
        _ = try? await Purchases.shared.recordPurchase(result)
        switch result {
        case .success(let result):
            guard case .verified(let transaction) = result else { throw Failure.unverified }
            await transaction.finish()
            subscribed = true
            let trial = transaction.offer?.paymentMode == .freeTrial
            if trial, let charge = transaction.expirationDate {
                await Self.remindBeforeCharge(on: charge)
            }
            return .purchased(Purchase(plan: plan, trial: trial, renews: transaction.expirationDate))
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Sincroniza com a App Store e diz se a conta tem um plano ativo.
    func restore() async -> Bool {
        try? await AppStore.sync()
        _ = try? await Purchases.shared.syncPurchases()
        await refreshAccess()
        return subscribed == true
    }

    private func hasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, TobiPlan(rawValue: transaction.productID) != nil,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    /// Quando chega o aviso de fim do teste: um dia antes da cobrança.
    static func reminderDate(beforeCharge charge: Date) -> Date {
        charge.addingTimeInterval(-24 * 3600)
    }

    /// A promessa da linha do tempo: um aviso um dia antes da primeira cobrança.
    static func remindBeforeCharge(on charge: Date) async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        let fire = reminderDate(beforeCharge: charge)
        guard fire > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tobi"
        content.body = "Amanhã acaba seu teste grátis. Se não quiser continuar, é só cancelar nos Ajustes do iPhone."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSinceNow, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "trial.reminder", content: content, trigger: trigger))
    }

    // MARK: Cortesia

    /// As horas que o Tobi dá pra quem fecha o paywall.
    static let freePassHours = 24.0

    /// Até quando a cortesia vale. Depois disso, sem plano, o app mostra o paywall.
    static var freePassUntil: Date? {
        UserDefaults.standard.object(forKey: "freePassUntil") as? Date
    }

    func grantFreePass() {
        UserDefaults.standard.set(Date.now.addingTimeInterval(Self.freePassHours * 3600), forKey: "freePassUntil")
        watchFreePass()
    }

    /// Apaga a cortesia na hora em que ela acaba, mesmo com o app aberto.
    private func watchFreePass() {
        passWatch?.cancel()
        guard let ends = Self.freePassUntil, ends > .now else {
            freePassActive = false
            return
        }
        freePassActive = true
        passWatch = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ends.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            self?.freePassActive = false
        }
    }
}
