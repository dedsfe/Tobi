import SwiftUI

/// As formas de registrar, na ordem do palco. Ícones e cores são os mesmos da barra do teclado.
enum InputMethod: CaseIterable, Identifiable {
    case write, speak, scan

    var id: Self { self }

    var title: String {
        switch self {
        case .write: "Escrever"
        case .speak: "Falar"
        case .scan: "Escanear"
        }
    }

    var symbol: String {
        switch self {
        case .write: "pencil.line"
        case .speak: "mic.fill"
        case .scan: "barcode.viewfinder"
        }
    }

    var color: Color {
        switch self {
        case .write: .indigo
        case .speak: .blue
        case .scan: .purple
        }
    }
}

/// O que cada cena escreve, fala ou lê. Os testes garantem que a base entende tudo.
enum InputMethodsDemo {
    static let writeLines = ["1 banana", "iogurte natural com granola"]
    static let spokenLine = "um pão de queijo e um café"
    static let scannedProduct = BrandProductInfo(
        barcode: "7894321242521", name: "Toddynho Levinho", brand: "Toddynho", quantity: "200 ml",
        servingGrams: 200, per100: Nutrition(kcal: 55, protein: 2.5, carbs: 9, fat: 1, sugar: 8)
    )
    /// Tempo de cada cena antes de passar pra próxima.
    static let sceneSeconds = 4.2
}

/// Palco de vidro que mostra o app em ação, uma forma de registrar por vez, com pílulas de story
/// embaixo: a da vez enche enquanto a cena roda; tocar numa pílula pula pra cena dela.
struct InputMethodsShowcase: View {
    @State private var current: InputMethod = .write
    /// Muda a cada cena (mesmo repetindo a mesma), pra a cena recomeçar do zero.
    @State private var run = 0
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                switch current {
                case .write: WriteScene()
                case .speak: SpeakScene()
                case .scan: ScanScene()
                }
            }
            .id(run)
            .transition(.blurReplace)
            .frame(maxWidth: .infinity)
            .frame(height: 262)
            .clipShape(.rect(cornerRadius: 32))
            .glassEffect(.regular, in: .rect(cornerRadius: 32))

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(InputMethod.allCases) { method in
                        pill(method)
                    }
                }
            }
        }
        .task(id: run) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { progress = 0 }
            withAnimation(.linear(duration: InputMethodsDemo.sceneSeconds)) { progress = 1 }
            try? await Task.sleep(for: .seconds(InputMethodsDemo.sceneSeconds))
            guard !Task.isCancelled else { return }
            let all = InputMethod.allCases
            show(all[(all.firstIndex(of: current)! + 1) % all.count])
        }
        .sensoryFeedback(.selection, trigger: current)
    }

    private func show(_ method: InputMethod) {
        withAnimation(Motion.surface) {
            current = method
            run += 1
        }
    }

    private func pill(_ method: InputMethod) -> some View {
        let isCurrent = method == current
        return Button { show(method) } label: {
            HStack(spacing: 6) {
                Image(systemName: method.symbol)
                    .foregroundStyle(method.color)
                Text(method.title)
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(alignment: .leading) {
                // A pílula da vez enche como um story.
                if isCurrent {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(method.color.opacity(0.16))
                            .frame(width: proxy.size.width * progress)
                    }
                }
            }
            .clipShape(.capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .opacity(isCurrent ? 1 : 0.75)
        .animation(Motion.quick, value: isCurrent)
    }
}

// MARK: - Cenas

/// Uma linha da nota como no app: o texto e, do lado, o rótulo de calorias de verdade (`KcalLabel`).
private struct NoteLinePreview: View {
    let text: String
    var isSearching = false
    var showsKcal = true

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(Color(uiColor: .label))
            Spacer(minLength: 12)
            if showsKcal {
                KcalLabel(mark: LineMark(estimate: FoodParser.shared.estimate(text), isSearching: isSearching))
            }
        }
    }
}

/// Escrever: as linhas se digitam, o ✨ aparece enquanto escreve e vira as calorias.
private struct WriteScene: View {
    @State private var typed: [String] = []
    @State private var writing: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(typed.indices, id: \.self) { index in
                NoteLinePreview(text: typed[index], isSearching: writing == index)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            for (index, line) in InputMethodsDemo.writeLines.enumerated() {
                typed.append("")
                writing = index
                for letter in line {
                    guard !Task.isCancelled else { return }
                    typed[index].append(letter)
                    try? await Task.sleep(for: .milliseconds(55))
                }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(Motion.quick) { writing = nil }
                try? await Task.sleep(for: .milliseconds(450))
            }
        }
    }
}

/// Falar: a luz da voz embaixo, a cápsula do microfone ouvindo, as palavras surgindo uma a uma
/// e virando uma linha com calorias.
private struct SpeakScene: View {
    @State private var words = 0
    @State private var done = false
    private let spoken = InputMethodsDemo.spokenLine.split(separator: " ").map(String.init)

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if done {
                    NoteLinePreview(text: InputMethodsDemo.spokenLine)
                        .transition(.blurReplace)
                } else {
                    Text(spoken.prefix(words).joined(separator: " "))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(uiColor: .label))
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            Spacer(minLength: 0)
            ListeningCapsule(isListening: !done)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .bottom) { VoiceLight(isOn: !done) }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            for count in 1...spoken.count {
                guard !Task.isCancelled else { return }
                withAnimation(Motion.quick) { words = count }
                try? await Task.sleep(for: .milliseconds(330))
            }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(Motion.surface) { done = true }
        }
    }
}

/// Cápsula do microfone enquanto ouve, no desenho da barra do teclado: barrinhas nas cores da voz.
private struct ListeningCapsule: View {
    let isListening: Bool
    @State private var pulse = false
    private let colors = [Theme.protein, Theme.carbs, Theme.sugar, Theme.fat, Theme.sodium]

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(colors.indices, id: \.self) { band in
                    Capsule()
                        .fill(colors[band])
                        .frame(width: 4, height: isListening && pulse ? [16, 22, 12, 20, 14][band] : 5)
                        .animation(isListening
                                   ? .easeInOut(duration: 0.28 + Double(band) * 0.05).repeatForever(autoreverses: true)
                                   : Motion.quick, value: pulse)
                }
            }
            .frame(height: 24)
            Image(systemName: isListening ? "stop.fill" : "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(uiColor: .label))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .glassEffect(.regular, in: .capsule)
        .onAppear { pulse = true }
    }
}

/// A nuvem de luz da voz, leve: três manchas desfocadas que respiram.
private struct VoiceLight: View {
    let isOn: Bool
    @State private var breathe = false

    var body: some View {
        HStack(spacing: -40) {
            ForEach(Array([Theme.protein, Theme.carbs, Theme.fat].enumerated()), id: \.offset) { index, color in
                Ellipse()
                    .fill(color)
                    .frame(width: 150, height: breathe ? 120 : 80)
                    .animation(.easeInOut(duration: 1.1 + Double(index) * 0.2).repeatForever(autoreverses: true),
                               value: breathe)
            }
        }
        .blur(radius: 34)
        .opacity(isOn ? 0.55 : 0)
        .offset(y: 50)
        .animation(Motion.surface, value: isOn)
        .allowsHitTesting(false)
        .onAppear { breathe = true }
    }
}

/// Escanear: a mira lendo o código de barras e o produto subindo com as calorias.
private struct ScanScene: View {
    @State private var sweep = false
    @State private var found = false
    private let product = InputMethodsDemo.scannedProduct
    private var kcal: Int { Int((product.per100.kcal * (product.servingGrams ?? 100) / 100).rounded()) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                Image(systemName: "barcode")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color(uiColor: .label).opacity(0.75))
                RoundedRectangle(cornerRadius: 3)
                    .fill(InputMethod.scan.color)
                    .frame(width: 130, height: 3)
                    .shadow(color: InputMethod.scan.color, radius: 6)
                    .offset(y: sweep ? 34 : -34)
                    .opacity(found ? 0 : 1)
            }
            .frame(width: 170, height: 110)
            .overlay { ScanCorners().stroke(Color(uiColor: .label).opacity(0.8),
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)) }
            .scaleEffect(found ? 0.82 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, found ? 14 : 70)

            if found {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name)
                            .font(.system(size: 17, weight: .semibold))
                        Text("\(product.brand ?? "") · \(product.quantity ?? "")")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text("\(kcal) cal")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(Color(uiColor: .label))
                .padding(18)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.success, trigger: found)
        .task {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { sweep = true }
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.surface) { found = true }
        }
    }
}

/// Os quatro cantos da mira, como no scanner do app.
private struct ScanCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 22
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
                                 (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
                                 (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}
