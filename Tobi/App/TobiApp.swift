import SwiftUI
import SwiftData

@main
struct TobiApp: App {
    /// Nos testes de interface o app começa vazio e não mexe nos dados de verdade.
    private let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    var body: some Scene {
        WindowGroup {
            DayView()
        }
        .modelContainer(for: [DayNote.self, BrandProduct.self], inMemory: inMemory)
    }
}
