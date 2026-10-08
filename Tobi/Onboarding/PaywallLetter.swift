import SwiftUI

/// Tocou no X do paywall: chega uma carta do Tobi. O envelope treme, a aba abre, o cartão sai
/// dobrado ao meio, abre e o Tobi escreve as 24 horas de cortesia, assina e carimba a patinha.
/// Aceitou: o cartão fecha e volta pro envelope. Tocar no cartão termina de escrever na hora.
struct TobiLetter: View {
    let onAccept: () -> Void
    let onBack: () -> Void

    private static let hours = Int(TobiStore.freePassHours)
    /// Envelope e cartão na mesma proporção: o cartão fechado (metade da altura) cabe com folga.
    private static let envelope = CGSize(width: 324, height: 204)
    private static let cardHeight: CGFloat = 380
    /// Fechado, o cartão ocupa o envelope quase de borda a borda (4 pt de folga de cada lado),
    /// pra não sobrar fundo escuro aparecendo nos cantos.
    private static let foldedScale: CGFloat = 0.875
    /// Posições a partir do centro: o envelope um pouco abaixo; o cartão dentro dele (com a dobra
    /// 6 pt abaixo da boca), saindo e aberto.
    private static let envelopeY: CGFloat = 40
    private static let insideY: CGFloat = -56
    private static let pulledY: CGFloat = -186

    static let paper = Color(light: .white, dark: Color(white: 0.15))
    static let ink = Color(light: Color(red: 0.12, green: 0.12, blue: 0.22), dark: Color(white: 0.94))

    @State private var arrived = false
    @State private var envelopeAway = false
    @State private var flap = 0.0
    /// Passou de 90°: a aba vai pra trás do cartão.
    @State private var flapBehind = false
    @State private var wiggle = 0
    @State private var cardY = Self.insideY
    @State private var cardScale = Self.foldedScale
    @State private var cardTilt = 0.0
    @State private var cardGone = false
    /// Metade de cima do cartão: 180 é fechado, 0 é aberto.
    @State private var fold = 180.0
    /// Tinta de cada bloco: saudação, texto, despedida, assinatura e P.S.
    @State private var ink = Array(repeating: 0.0, count: 5)
    @State private var stamped = false
    @State private var buttonsIn = false
    @State private var skipped = false
    @State private var busy = false
    @State private var until = Date.now.addingTimeInterval(TobiStore.freePassHours * 3600)
    /// Gatilhos dos toques: chegada, batidinhas, aba, papel, dobra, assentar e caneta.
    @State private var arrivals = 0
    @State private var bumps = 0
    @State private var flips = 0
    @State private var pulls = 0
    @State private var folds = 0
    @State private var flats = 0
    @State private var scratches = 0
    @Environment(\.tobiReactions) private var tobi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let greeting = "Ei, espera aí!"
    private static let message = "Vou te dar \(hours) horas de graça pra testar. Eu pago a IA, não consigo dar o app de graça."
    private static let farewell = "Com carinho,"

    private var postscript: String {
        "P.S.: vale até amanhã às \(until.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if arrived {
                    scene
                        .transition(.emerge)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 6) {
                PaywallButton(title: "Quero minhas \(Self.hours) horas", action: accept)
                Button("Prefiro ver os planos", action: leave)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
            .reveal(buttonsIn, order: 0)
            .allowsHitTesting(buttonsIn && !busy)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: arrivals)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: bumps)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: flips)
        .sensoryFeedback(.impact(weight: .light), trigger: pulls)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.9), trigger: folds)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: flats)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.3), trigger: scratches)
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .task { await deliver() }
    }

    // MARK: Cena

    /// Envelope e cartão numa pilha só, pro cartão entrar e sair entre o fundo e as abas da frente.
    private var scene: some View {
        let size = Self.envelope
        let envelopeY = Self.envelopeY + (envelopeAway ? 180 : 0)
        let envelopeOpacity: Double = envelopeAway ? 0 : 1
        return ZStack {
            EnvelopeBack()
                .frame(width: size.width, height: size.height)
                .offset(y: envelopeY)
                .opacity(envelopeOpacity)
                .zIndex(0)

            // Desce 1 pt pra dentro do fundo: aberta, a dobra emenda sem fio claro.
            EnvelopeFlapView(angle: flap)
                .frame(width: size.width, height: size.height * EnvelopeFlap.depth)
                .offset(y: envelopeY - size.height * (1 - EnvelopeFlap.depth) / 2 + 1)
                .opacity(envelopeOpacity)
                .zIndex(flapBehind ? 1 : 4)

            card
                .zIndex(2)

            EnvelopeFront()
                .frame(width: size.width, height: size.height)
                .offset(y: envelopeY)
                .opacity(envelopeOpacity)
                .allowsHitTesting(false)
                .zIndex(3)
        }
        .keyframeAnimator(initialValue: 0.0, trigger: wiggle) { view, angle in
            view.rotationEffect(.degrees(angle))
        } keyframes: { _ in
            SpringKeyframe(-4, duration: 0.11)
            SpringKeyframe(3, duration: 0.11)
            SpringKeyframe(-1.5, duration: 0.1)
            SpringKeyframe(0, duration: 0.18)
        }
    }

    // MARK: Cartão dobrado ao meio

    private var card: some View {
        let halfHeight = Self.cardHeight / 2
        return VStack(spacing: 0) {
            FoldPanel(angle: fold) {
                half(of: 0)
            } back: {
                CardCover()
            }
            .frame(height: halfHeight)
            .zIndex(1)

            half(of: 1)
                .frame(height: halfHeight)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 24, y: 14)
        .padding(.horizontal, 16)
        .scaleEffect(cardScale)
        .rotationEffect(.degrees(cardTilt))
        .offset(y: cardY + (cardGone ? 160 : 0))
        .opacity(cardGone ? 0 : 1)
        .contentShape(.rect)
        .onTapGesture(perform: finishWriting)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([Self.greeting, Self.message, Self.farewell, "Tobi", postscript].joined(separator: " "))
    }

    /// Uma metade do cartão: a frente inteira desenhada e recortada na dobra.
    private func half(of index: Int) -> some View {
        face
            .frame(height: Self.cardHeight)
            .offset(y: -CGFloat(index) * Self.cardHeight / 2)
            .frame(height: Self.cardHeight / 2, alignment: .top)
            .clipped()
    }

    /// A frente do cartão aberto: saudação, recado, despedida, assinatura com carimbo e o P.S.
    private var face: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.greeting)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Self.ink)
                .textRenderer(InkRenderer(progress: ink[0]))

            Text(Self.message)
                .font(.system(size: 20, design: .serif))
                .foregroundStyle(Self.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .textRenderer(InkRenderer(progress: ink[1]))
                .padding(.top, 14)

            Spacer(minLength: 16)

            Text(Self.farewell)
                .font(.system(size: 18, design: .serif).italic())
                .foregroundStyle(.secondary)
                .textRenderer(InkRenderer(progress: ink[2]))

            HStack(alignment: .center, spacing: 12) {
                Text("Tobi")
                    .font(.custom("SnellRoundhand-Bold", size: 48))
                    .foregroundStyle(.indigo)
                    .mask(alignment: .leading) { InkSweep(progress: ink[3]) }
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.indigo)
                    .rotationEffect(.degrees(-14))
                    .scaleEffect(stamped ? 1 : 2.4)
                    .opacity(stamped ? 1 : 0)
                    .animation(Motion.surface, value: stamped)
            }
            .frame(height: 58)

            Text(postscript)
                .font(.system(size: 15, weight: .medium, design: .serif).italic())
                .foregroundStyle(.indigo)
                .textRenderer(InkRenderer(progress: ink[4]))
                .padding(.top, 10)
        }
        .padding(.horizontal, 28)
        .padding(.top, 30)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Self.paper, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            // O vinco do meio fica no papel depois de aberto.
            Crease().opacity(fold < 90 ? 1 : 0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.07))
        }
    }

    // MARK: Coreografia

    private func deliver() async {
        if reduceMotion {
            arrived = true
            envelopeAway = true
            cardY = 0
            cardScale = 1
            fold = 0
            flap = 180
            flapBehind = true
            finishWriting()
            return
        }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(Motion.surface) { arrived = true }
        arrivals += 1
        tobi.mood(.curious)

        // Chegou: treme duas vezes, como quem bate na porta.
        try? await Task.sleep(for: .milliseconds(480))
        wiggle += 1
        bumps += 1
        try? await Task.sleep(for: .milliseconds(220))
        bumps += 1

        // Abre a aba em dois tempos, pra ela passar pra trás do cartão no meio do giro.
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.easeIn(duration: 0.17)) { flap = 90 }
        try? await Task.sleep(for: .milliseconds(170))
        flapBehind = true
        withAnimation(.easeOut(duration: 0.26)) { flap = 180 }
        flips += 1

        // O cartão sobe meio torto; depois o envelope cai e o cartão vem pro centro.
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(Motion.surface) {
            cardY = Self.pulledY
            cardTilt = -3
        }
        pulls += 1
        try? await Task.sleep(for: .milliseconds(520))
        withAnimation(Motion.surface) {
            envelopeAway = true
            cardY = 0
            cardScale = 1
            cardTilt = 0
        }

        // Abre o cartão e assenta.
        try? await Task.sleep(for: .milliseconds(440))
        withAnimation(Motion.surface) { fold = 0 }
        folds += 1
        try? await Task.sleep(for: .milliseconds(380))
        flats += 1
        tobi.mood(.attentive)

        try? await Task.sleep(for: .milliseconds(200))
        guard await write(0, characters: Self.greeting.count),
              await write(1, characters: Self.message.count),
              await write(2, characters: Self.farewell.count) else { return }
        withAnimation { buttonsIn = true }
        guard await write(3, characters: 4, pace: 0.13) else { return }
        stamped = true
        tobi.celebrate()
        try? await Task.sleep(for: .milliseconds(260))
        _ = await write(4, characters: postscript.count)
    }

    /// Escreve um bloco no ritmo do texto, com a caneta riscando no dedo. Falso se a pessoa pulou.
    private func write(_ index: Int, characters: Int, pace: Double = 0.022) async -> Bool {
        guard !skipped else { return false }
        let duration = 0.15 + Double(characters) * pace
        withAnimation(.linear(duration: duration)) { ink[index] = 1 }
        var elapsed = 0.0
        while elapsed < duration {
            guard !skipped else { return false }
            scratches += 1
            try? await Task.sleep(for: .milliseconds(70))
            elapsed += 0.07
        }
        try? await Task.sleep(for: .milliseconds(120))
        return !skipped
    }

    private func finishWriting() {
        guard !skipped, !busy else { return }
        skipped = true
        withAnimation(Motion.quick) {
            ink = ink.map { _ in 1 }
            buttonsIn = true
        }
        if !stamped {
            stamped = true
            tobi.celebrate()
        }
    }

    // MARK: Saídas

    /// Aceitou: o cartão fecha, volta pro envelope, a aba fecha e aí o Tobi comemora.
    private func accept() {
        guard !busy else { return }
        busy = true
        skipped = true
        guard !reduceMotion else { return onAccept() }
        Task {
            withAnimation(Motion.exit) { buttonsIn = false }
            withAnimation(Motion.surface) { fold = 180 }
            folds += 1
            try? await Task.sleep(for: .milliseconds(340))
            withAnimation(Motion.surface) {
                cardScale = Self.foldedScale
                cardY = Self.pulledY
                cardTilt = -3
                envelopeAway = false
            }
            try? await Task.sleep(for: .milliseconds(440))
            withAnimation(Motion.surface) {
                cardY = Self.insideY
                cardTilt = 0
            }
            pulls += 1
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeIn(duration: 0.15)) { flap = 90 }
            try? await Task.sleep(for: .milliseconds(150))
            flapBehind = false
            withAnimation(.easeOut(duration: 0.22)) { flap = 0 }
            try? await Task.sleep(for: .milliseconds(200))
            arrivals += 1
            wiggle += 1
            onAccept()
        }
    }

    /// Quer ver os planos: o cartão desliza pra baixo e some.
    private func leave() {
        guard !busy else { return }
        busy = true
        skipped = true
        tobi.mood(.joyful)
        withAnimation(Motion.exit) {
            buttonsIn = false
            cardGone = true
        }
        Task {
            try? await Task.sleep(for: .seconds(Motion.exitDuration))
            onBack()
        }
    }
}

// MARK: - Papel

/// A metade de cima do cartão. Gira pela dobra do meio e mostra a capa quando passa de 90°,
/// com sombra no vinco enquanto está inclinada.
private struct FoldPanel<Front: View, Back: View>: View, Animatable {
    var angle: Double
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showsBack = abs(angle) > 90
        let lean = abs(sin(angle * .pi / 180))
        ZStack {
            front.opacity(showsBack ? 0 : 1)
            // Girado 180°, o verso apareceria de ponta-cabeça: desvira antes.
            back.scaleEffect(y: -1).opacity(showsBack ? 1 : 0)
        }
        .overlay {
            LinearGradient(colors: [.black.opacity(0.2 * lean), .clear], startPoint: .bottom, endPoint: .top)
                .allowsHitTesting(false)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.22)
    }
}

/// A capa do cartão fechado: papel liso com a patinha do Tobi no meio.
/// Fechado, ela fica embaixo da dobra; por isso os cantos redondos são os de baixo.
private struct CardCover: View {
    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18, style: .continuous)
        shape
            .fill(TobiLetter.paper)
            .overlay { shape.strokeBorder(.primary.opacity(0.07)) }
            .overlay {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.indigo.opacity(0.35))
            }
    }
}

/// O vinco do meio: uma sombra fina com um brilho embaixo.
private struct Crease: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.black.opacity(0.05)).frame(height: 1)
            Rectangle().fill(.white.opacity(0.5)).frame(height: 1)
        }
        .allowsHitTesting(false)
    }
}

/// A tinta chega letra por letra: cada uma sobe um tiquinho, ganha foco e cor.
private struct InkRenderer: TextRenderer, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Quantas letras a borda da tinta ocupa.
    private static let spread = 6.0

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let total = layout.reduce(0) { lines, line in lines + line.reduce(0) { $0 + $1.count } }
        let head = progress * (Double(total) + Self.spread)
        var index = 0.0
        for line in layout {
            for run in line {
                for glyph in run {
                    let amount = min(1, max(0, (head - index) / Self.spread))
                    index += 1
                    guard amount > 0 else { continue }
                    var copy = context
                    copy.opacity = amount
                    if amount < 1 {
                        copy.translateBy(x: 0, y: (1 - amount) * 4)
                        copy.addFilter(.blur(radius: (1 - amount) * 2.5))
                    }
                    copy.draw(glyph)
                }
            }
        }
    }
}

/// A assinatura entra num traço só, da esquerda pra direita, com a borda macia.
private struct InkSweep: View {
    let progress: Double

    var body: some View {
        LinearGradient(stops: [.init(color: .black, location: 0),
                               .init(color: .black, location: 0.8),
                               .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
            .scaleEffect(x: max(0.001, progress * 1.25), y: 1, anchor: .leading)
    }
}

// MARK: - Envelope

/// O fundo do envelope por dentro: escuro, com forro de patinhas.
private struct EnvelopeBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.indigo.mix(with: .black, by: 0.35))
            .overlay { PawLining() }
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }
}

/// A frente do envelope: as abas dos lados e a de baixo, que se encontram no meio.
private struct EnvelopeFront: View {
    var body: some View {
        ZStack {
            EnvelopeSide(leading: true)
                .fill(Color.indigo.mix(with: .white, by: 0.05))
            EnvelopeSide(leading: false)
                .fill(Color.indigo.mix(with: .white, by: 0.05))
            EnvelopeBottom()
                .fill(Color.indigo)
                .shadow(color: .black.opacity(0.15), radius: 3, y: -1)
                .overlay(alignment: .bottom) {
                    Text("pra você")
                        .font(.custom("SnellRoundhand-Bold", size: 24))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.bottom, 18)
                }
        }
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }
}

/// Aba do lado: do canto de cima ao de baixo, com a ponta no meio do envelope.
private struct EnvelopeSide: Shape {
    let leading: Bool

    func path(in rect: CGRect) -> Path {
        let edge = leading ? rect.minX : rect.maxX
        let tip = CGPoint(x: rect.midX + (leading ? -6 : 6), y: rect.minY + rect.height * 0.56)
        return Path { path in
            path.move(to: CGPoint(x: edge, y: rect.minY))
            path.addLine(to: tip)
            path.addLine(to: CGPoint(x: edge, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// Aba de baixo: dos cantos de baixo até um pouco acima do meio, com a ponta arredondada.
private struct EnvelopeBottom: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.46)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: tip.x - 26, y: tip.y + 14))
        path.addQuadCurve(to: CGPoint(x: tip.x + 26, y: tip.y + 14), control: tip)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A aba de cima. Fechada mostra a patinha que lacra; aberta mostra o forro.
private struct EnvelopeFlapView: View, Animatable {
    var angle: Double

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    /// Os cantos da dobra acompanham os cantos arredondados do envelope.
    private static let corners = UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous)

    var body: some View {
        let showsInside = angle > 90
        let closed = max(0, cos(angle * .pi / 180))
        ZStack {
            EnvelopeFlap()
                .fill(Color.indigo.mix(with: .white, by: 0.12))
                .clipShape(Self.corners)
                .overlay(alignment: .bottom) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(.bottom, 18)
                }
                .shadow(color: .black.opacity(0.25 * closed), radius: 5, y: 3)
                .opacity(showsInside ? 0 : 1)
            EnvelopeFlap()
                .fill(Color.indigo.mix(with: .black, by: 0.35))
                .overlay { PawLining() }
                .clipShape(EnvelopeFlap())
                .clipShape(Self.corners)
                .opacity(showsInside ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.3)
    }
}

/// A aba: triângulo dos cantos de cima até a ponta arredondada, cobrindo o encontro das abas.
private struct EnvelopeFlap: Shape {
    /// Quanto da altura do envelope a aba cobre.
    static let depth: CGFloat = 0.6

    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: tip.x - 26, y: tip.y - 15))
        path.addQuadCurve(to: CGPoint(x: tip.x + 26, y: tip.y - 15), control: tip)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Forro de dentro do envelope: patinhas espalhadas, bem apagadas.
private struct PawLining: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(0..<10, id: \.self) { column in
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 11))
                            .rotationEffect(.degrees((row + column).isMultiple(of: 2) ? -20 : 18))
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? 0 : 16)
            }
        }
        .foregroundStyle(.white.opacity(0.09))
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
