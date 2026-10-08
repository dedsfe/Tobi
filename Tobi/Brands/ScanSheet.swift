import AVFoundation
import SwiftUI

/// Tela da câmera: mira no código, trava quando lê, mostra o produto e só então devolve.
struct ScanSheet: View {
    /// O produto e a linha pronta pra nota ("2 colheres de sopa de Leite Condensado Moça").
    var onProduct: (BrandProductInfo, String) -> Void
    /// Não achou ou não tem tabela: fecha e deixa a pessoa escrever o nome na linha.
    var onWriteInstead: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    private enum Status: Equatable {
        case scanning
        case looking
        case found(BrandProductInfo)
        case noNutrition(String)
        case notFound
        case offline

        var isProblem: Bool {
            switch self {
            case .noNutrition, .notFound, .offline: true
            case .scanning, .looking, .found: false
            }
        }
    }

    @State private var status = Status.scanning
    /// Troca pra recriar a câmera depois de um "não achei" ou "escanear outro".
    @State private var attempt = 0
    @State private var torchOn = false

    var body: some View {
        ZStack {
            if BarcodeScanner.isAvailable {
                BarcodeScanner { code in lookUp(code) }
                    .id(attempt)
                    .ignoresSafeArea()
                ScanReticle(isLocked: status != .scanning)
                    .ignoresSafeArea()
            } else {
                Theme.background.ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                card
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .animation(Motion.surface, value: status)
        .sensoryFeedback(trigger: status) { _, new in
            switch new {
            case .looking: .impact(weight: .medium)
            case .found: .success
            case .noNutrition, .notFound, .offline: .warning
            case .scanning: nil
            }
        }
        .onDisappear { Torch.set(false) }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Barra de cima

    private var topBar: some View {
        HStack {
            Button("Fechar", systemImage: "xmark") { dismiss() }
            Spacer()
            if Torch.isAvailable {
                Button(torchOn ? "Desligar lanterna" : "Ligar lanterna",
                       systemImage: torchOn ? "flashlight.on.fill" : "flashlight.off.fill") {
                    torchOn.toggle()
                    Torch.set(torchOn)
                }
                .contentTransition(.symbolEffect(.replace))
            }
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Cartão de baixo

    @ViewBuilder
    private var card: some View {
        Group {
            switch status {
            case .found(let product):
                ProductCard(product: product, onAdd: { line in add(product, line) }, onAnother: scanAgain)
            default:
                messageCard
            }
        }
        .transition(.emerge)
    }

    private var messageCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.pulse, isActive: status == .looking)
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .contentTransition(.opacity)
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.emerge)
            }
            if status.isProblem {
                HStack(spacing: 10) {
                    Button("Escrever o nome") {
                        dismiss()
                        onWriteInstead()
                    }
                    .buttonStyle(.glass)
                    Button("Tentar de novo", action: scanAgain)
                        .buttonStyle(.glassProminent)
                }
                .font(.system(size: 15, weight: .semibold))
                .transition(.emerge)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private var icon: String {
        switch status {
        case .scanning: "barcode.viewfinder"
        case .looking: "magnifyingglass"
        case .noNutrition: "list.bullet.rectangle"
        case .notFound: "questionmark"
        case .offline: "wifi.slash"
        case .found: "checkmark"
        }
    }

    private var title: String {
        guard BarcodeScanner.isAvailable else { return "Câmera indisponível neste aparelho" }
        switch status {
        case .scanning: return "Aponte pro código de barras"
        case .looking: return "Procurando o produto…"
        case .noNutrition: return "Achei, mas sem tabela"
        case .notFound: return "Não achei esse produto"
        case .offline: return "Sem conexão pra buscar"
        case .found: return ""
        }
    }

    private var detail: String? {
        switch status {
        case .noNutrition(let name): "\(name) ainda não tem calorias cadastradas no Open Food Facts."
        case .notFound: "Esse código ainda não está no Open Food Facts."
        case .offline: "Confere a internet e tenta de novo."
        default: nil
        }
    }

    // MARK: - Ações

    private func lookUp(_ code: String) {
        status = .looking
        Task {
            do {
                switch try await OpenFoodFacts.product(barcode: code) {
                case .found(let product): status = .found(product)
                case .noNutrition(let name): status = .noNutrition(name)
                case .notFound: status = .notFound
                }
            } catch {
                status = .offline
            }
        }
    }

    private func add(_ product: BrandProductInfo, _ line: String) {
        onProduct(product, line)
        dismiss()
    }

    private func scanAgain() {
        status = .scanning
        attempt += 1
    }
}

// MARK: - Produto encontrado

/// O produto lido. Primeiro mostra o que é; ao tocar em Adicionar, pergunta quanto a pessoa
/// comeu (porção, colher, copo, embalagem, gramas) e já mostra as calorias dessa quantidade.
private struct ProductCard: View {
    let product: BrandProductInfo
    var onAdd: (_ line: String) -> Void
    var onAnother: () -> Void

    @State private var shown = false
    @State private var askingAmount = false
    @State private var unit: AmountUnit
    @State private var count: Double = 1
    private let units: [AmountUnit]

    init(product: BrandProductInfo, onAdd: @escaping (String) -> Void, onAnother: @escaping () -> Void) {
        self.product = product
        self.onAdd = onAdd
        self.onAnother = onAnother
        let units = AmountUnit.options(for: product)
        self.units = units
        _unit = State(initialValue: units[0])
    }

    private var grams: Double { unit.grams * count }
    private var nutrition: Nutrition { product.per100.scaled(by: grams / 100) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 19, weight: .semibold))
                    .lineLimit(2)
                    .reveal(shown, order: 0)
                Text([product.brand, product.quantity].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .reveal(shown, order: 1)
            }

            if askingAmount {
                amountPicker
                    .transition(.emerge)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("🔥").font(.system(size: 20))
                Text(Int(nutrition.kcal.rounded()).formatted())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: nutrition.kcal))
                Text(askingAmount ? "cal" : "cal por \(unit.label(count: 1))")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .reveal(shown, order: 2)

            HStack(spacing: 14) {
                macro("C", nutrition.carbs, Theme.carbs)
                macro("P", nutrition.protein, Theme.protein)
                macro("G", nutrition.fat, Theme.fat)
            }
            .reveal(shown, order: 3)

            HStack(spacing: 10) {
                Button(askingAmount ? "Voltar" : "Escanear outro") {
                    if askingAmount {
                        withAnimation(Motion.surface) { askingAmount = false }
                    } else {
                        onAnother()
                    }
                }
                .buttonStyle(.glass)
                Button(askingAmount ? "Adicionar à nota" : "Adicionar") {
                    if askingAmount {
                        onAdd(unit.line(count: count, name: product.name))
                    } else {
                        withAnimation(Motion.surface) { askingAmount = true }
                    }
                }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)
            }
            .font(.system(size: 16, weight: .semibold))
            .controlSize(.large)
            .reveal(shown, order: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .animation(Motion.quick, value: count)
        .animation(Motion.quick, value: unit)
        .sensoryFeedback(.selection, trigger: count)
        .sensoryFeedback(.selection, trigger: unit)
        .onAppear { shown = true }
    }

    /// Medida em fichas + quantidade com − e +, do jeito que se fala: "2 colheres de sopa".
    private var amountPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quanto você comeu?")
                .font(.system(size: 15, weight: .semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(units) { option in
                        Button {
                            unit = option
                            count = option.defaultCount
                        } label: {
                            Text(option.chip)
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(unit == option ? Color.white : Color.primary)
                        .glassEffect(unit == option ? .regular.tint(.indigo).interactive() : .regular.interactive(),
                                     in: .capsule)
                    }
                }
            }
            .scrollClipDisabled()

            HStack(spacing: 18) {
                stepButton("Menos", "minus") { count = max(unit.step, count - unit.step) }
                    .disabled(count <= unit.step)
                Text(unit.label(count: count))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: count))
                    .frame(maxWidth: .infinity)
                stepButton("Mais", "plus") { count += unit.step }
            }
        }
    }

    private func stepButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: icon, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .bold))
            .frame(width: 44, height: 44)
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    private func macro(_ letter: String, _ grams: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(letter)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text("\(grams.formatted(.number.precision(.fractionLength(0...1)))) g")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: grams))
        }
    }
}

/// Uma forma de dizer quanto comeu: porção do rótulo, medida caseira, a embalagem ou gramas.
/// Cada uma sabe escrever a linha de um jeito que o FoodParser lê de volta.
private struct AmountUnit: Identifiable, Equatable {
    enum Kind: Equatable { case portion, measure(String), package, grams }

    let kind: Kind
    /// Gramas (ou ml) de uma unidade.
    let grams: Double
    let isLiquid: Bool

    var id: String { chip }
    var step: Double { kind == .grams ? 10 : 0.5 }
    var defaultCount: Double { kind == .grams ? 100 : 1 }

    static func options(for product: BrandProductInfo) -> [AmountUnit] {
        let liquid = product.isLiquid
        var options: [AmountUnit] = []
        if let serving = product.servingGrams { options.append(.init(kind: .portion, grams: serving, isLiquid: liquid)) }
        let measures = FoodParser.shared.householdMeasures(for: product.name)
        for key in preferredMeasures where options.count < 4 {
            if let grams = measures[key] { options.append(.init(kind: .measure(key), grams: grams, isLiquid: liquid)) }
        }
        if let package = product.packageGrams { options.append(.init(kind: .package, grams: package, isLiquid: liquid)) }
        if options.isEmpty { options.append(.init(kind: .portion, grams: 100, isLiquid: liquid)) }
        options.append(.init(kind: .grams, grams: 1, isLiquid: liquid))
        return options
    }

    /// Medidas que fazem sentido mostrar, na ordem em que o brasileiro mais usa.
    private static let preferredMeasures = ["unidade", "colher de sopa", "colher de cha", "copo", "fatia",
                                            "xicara", "concha", "pedaco", "lata", "pote", "bola"]

    var chip: String {
        switch kind {
        case .portion: "Porção · \(Self.amount(grams)) \(isLiquid ? "ml" : "g")"
        case .measure(let key): Self.names[key]?.0.capitalizedFirst ?? key
        case .package: "Embalagem · \(Self.amount(grams)) \(isLiquid ? "ml" : "g")"
        case .grams: isLiquid ? "Mililitros" : "Gramas"
        }
    }

    /// "2 colheres de sopa", "meia porção", "150 g".
    func label(count: Double) -> String {
        if kind == .grams { return "\(Self.amount(count)) \(isLiquid ? "ml" : "g")" }
        let (singular, plural): (String, String) = switch kind {
        case .portion: ("porção", "porções")
        case .package: ("embalagem", "embalagens")
        case .measure(let key): Self.names[key] ?? (key, key)
        case .grams: ("g", "g")
        }
        if count == 0.5 { return "meia \(singular)" }
        return "\(Self.amount(count)) \(count > 1 ? plural : singular)"
    }

    /// A linha que vai pra nota.
    func line(count: Double, name: String) -> String {
        switch kind {
        case .grams: "\(Self.amount(count)) \(isLiquid ? "ml" : "g") de \(name)"
        case .package: "\(Self.amount(count * grams)) \(isLiquid ? "ml" : "g") de \(name)"
        default: "\(label(count: count)) de \(name)"
        }
    }

    private static func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "pt_BR")))
    }

    private static let names: [String: (String, String)] = [
        "unidade": ("unidade", "unidades"), "colher de sopa": ("colher de sopa", "colheres de sopa"),
        "colher de cha": ("colher de chá", "colheres de chá"), "copo": ("copo", "copos"),
        "fatia": ("fatia", "fatias"), "xicara": ("xícara", "xícaras"), "concha": ("concha", "conchas"),
        "pedaco": ("pedaço", "pedaços"), "lata": ("lata", "latas"), "pote": ("pote", "potes"),
        "bola": ("bola", "bolas"),
    ]
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

private extension BrandProductInfo {
    var isLiquid: Bool { quantity?.lowercased().contains(/\d\s*(ml|l|lt)\b/) ?? false }

    /// Peso da embalagem inteira, lido do rótulo ("395 g", "2l", "1 kg").
    var packageGrams: Double? {
        guard let match = quantity?.lowercased().firstMatch(of: /(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|lt)\b/),
              let value = Double(match.1.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return ["kg", "l", "lt"].contains(String(match.2)) ? value * 1000 : value
    }
}

// MARK: - Mira

/// Escurece em volta e deixa uma janela com cantos; quando lê o código, a mira aperta e acende.
private struct ScanReticle: View {
    let isLocked: Bool
    private let size = CGSize(width: 280, height: 160)

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(x: (proxy.size.width - size.width) / 2, y: proxy.size.height * 0.36 - size.height / 2,
                              width: size.width, height: size.height)
            ZStack {
                // Fundo escuro com a janela vazada.
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addRoundedRect(in: rect, cornerSize: CGSize(width: 24, height: 24))
                }
                .fill(.black.opacity(isLocked ? 0.55 : 0.4), style: FillStyle(eoFill: true))

                ReticleCorners()
                    .stroke(isLocked ? Theme.fiber : .white,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: rect.width, height: rect.height)
                    .scaleEffect(isLocked ? 0.9 : 1)
                    .shadow(color: (isLocked ? Theme.fiber : .white).opacity(0.5), radius: isLocked ? 12 : 4)
                    .position(x: rect.midX, y: rect.midY)
            }
            .animation(Motion.quick, value: isLocked)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Só os quatro cantos de um retângulo arredondado.
private struct ReticleCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let arm: CGFloat = 30, radius: CGFloat = 24
        var path = Path()
        for (x, y, dx, dy) in [(rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0),
                               (rect.minX, rect.maxY, 1.0, -1.0), (rect.maxX, rect.maxY, -1.0, -1.0)] {
            path.move(to: CGPoint(x: x, y: y + dy * (radius + arm)))
            path.addLine(to: CGPoint(x: x, y: y + dy * radius))
            path.addQuadCurve(to: CGPoint(x: x + dx * radius, y: y), control: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx * (radius + arm), y: y))
        }
        return path
    }
}

// MARK: - Lanterna

/// Lanterna da câmera traseira, pra ler código em cozinha escura.
enum Torch {
    static var isAvailable: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    static func set(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}
