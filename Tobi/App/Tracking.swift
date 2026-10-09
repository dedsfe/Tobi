import AppTrackingTransparency
import RevenueCat

/// O pedido de rastreamento da Apple (ATT), pra medir quais anúncios trouxeram a pessoa.
/// O iOS só mostra o aviso uma vez; nas outras aberturas isso só atualiza os identificadores.
enum Tracking {
    @MainActor
    static func request() async {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            // Deixa o dia aparecer primeiro, pra o aviso não cobrir a transição.
            try? await Task.sleep(for: .seconds(1.2))
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        // O RevenueCat repassa pros anúncios o IDFA, só se a pessoa deixou, e o IDFV.
        Purchases.shared.attribution.collectDeviceIdentifiers()
    }
}
