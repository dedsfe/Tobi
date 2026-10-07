import SwiftUI

/// Tela da câmera: lê o código, busca no Open Food Facts e devolve o produto.
struct ScanSheet: View {
    var onProduct: (BrandProductInfo) -> Void
    @Environment(\.dismiss) private var dismiss

    private enum Status: Equatable {
        case scanning
        case looking
        case notFound
        case offline
    }

    @State private var status = Status.scanning
    /// Troca pra recriar a câmera depois de um "não achei".
    @State private var attempt = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if BarcodeScanner.isAvailable {
                BarcodeScanner { code in lookUp(code) }
                    .id(attempt)
                    .ignoresSafeArea()
            } else {
                Theme.background
            }

            statusCard
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .animation(Motion.surface, value: status)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var statusCard: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .contentTransition(.opacity)
            if status == .notFound || status == .offline {
                Button("Tentar de novo") {
                    status = .scanning
                    attempt += 1
                }
                .buttonStyle(.glass)
                .transition(.emerge)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private var title: String {
        guard BarcodeScanner.isAvailable else { return "Câmera indisponível neste aparelho" }
        switch status {
        case .scanning: return "Aponte pro código de barras"
        case .looking: return "Procurando o produto…"
        case .notFound: return "Não achei esse produto"
        case .offline: return "Sem conexão pra buscar o produto"
        }
    }

    private func lookUp(_ code: String) {
        status = .looking
        Task {
            do {
                if let product = try await OpenFoodFacts.product(barcode: code) {
                    onProduct(product)
                    dismiss()
                } else {
                    status = .notFound
                }
            } catch {
                status = .offline
            }
        }
    }
}
