import SwiftUI

/// Tocou no X do paywall: chega uma carta do Tobi. O envelope treme, a aba abre, a carta sai
/// dobrada em três, desdobra e o Tobi escreve à mão as 24 horas de cortesia, assina e carimba.
/// Aceitou: a carta se dobra e volta pro envelope. Tocar na carta termina de escrever na hora.
struct TobiLetter: View {
    let onAccept: () -> Void
    let onBack: () -> Void

    private static let hours = Int(TobiStore.freePassHours)
    private static let envelope = CGSize(width: 300, height: 190)
    /// Altura da carta aberta; cada dobra é um terço.
    private static let sheetHeight: CGFloat = 342
    /// Dentro do envelope a carta dobrada fica menor, pra caber.
    private static let foldedScale: CGFloat = 0.78
    /// Onde o envelope fica (a partir do centro) e onde a carta fica dentro dele e saindo dele.
    private static let envelopeY: CGFloat = 40
    private static let insideY: CGFloat = 50
    private static let pulledY: CGFloat = -80

    static let paper = Color(light: .white, dark: Color(white: 0.16))
    static let ink = Color(light: Color(red: 0.13, green: 0.13, blue: 0.24), dark: Color(white: 0.93))

    @State private var arrived = false
    @State private var envelopeAway = false
    @State private var flap = 0.0
    /// Passou de 90°: a aba vai pra trás da carta.
    @State private var flapBehind = false
    @State private var wiggle = 0
    @State private var sheetY = Self.insideY
    @State private var sheetScale = Self.foldedScale
    @State private var sheetTilt = 0.0
    @State private var sheetGone = false
    /// Dobra de cima e de baixo: ±180 é fechada, 0 é aberta.
    @State private var topFold = 180.0
    @State private var bottomFold = -180.0
    @State private var ink = Array(repeating: 0.0, count: 8)
    @State private var writing: Int?
    @State private var stamped = false
    @State private var buttonsIn = false
    @State private var skipped = false
    @State private var busy = false
    @State private var until = Date.now.addingTimeInterval(TobiStore.freePassHours * 3600)
    /// Gatilhos dos toques: chegada, batidinhas, aba, papel, dobras, assentar e caneta.
    @State private var arrivals = 0
    @State private var bumps = 0
    @State private var flips = 0
    @State private var pulls = 0
    @State private var folds = 0
    @State private var flats = 0
    @State private var scratches = 0
    @Environment(\.tobiReactions) private var tobi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rows: [String] {
        ["Ei, espera aí!",
         "Vou te dar \(Self.hours) horas de graça",
         "pra testar.",
         "Eu pago a IA, não consigo dar",
         "o app de graça.",
         "Com carinho,"]
    }

    private var signature: Int { rows.count }
    private var postscript: Int { rows.count + 1 }
    private var postscriptText: String {
        "P.S.: vale até amanhã às \(until.formatted(date: .omitted, time: .shortened))"
    }

    /// Mão de gente: cada linha entorta e recua um tiquinho diferente.
    private static let tilts: [Double] = [-0.8, 0.4, -0.3, 0.5, -0.4, 0.6]
    private static let indents: [CGFloat] = [0, 2, 1, 3, 0, 8]

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

    /// Envelope e carta numa pilha só, pra carta poder entrar e sair entre o fundo e o bolso.
    private var scene: some View {
        let size = Self.envelope
        let envelopeY = Self.envelopeY + (envelopeAway ? 170 : 0)
        let envelopeOpacity: Double = envelopeAway ? 0 : 1
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.indigo.mix(with: .black, by: 0.3))
                .overlay { PawLining() }
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .frame(width: size.width, height: size.height)
                .offset(y: envelopeY)
                .opacity(envelopeOpacity)
                .zIndex(0)

            EnvelopeFlapView(angle: flap)
                .frame(width: size.width, height: size.height * 0.6)
                .offset(y: envelopeY - size.height * 0.2)
                .opacity(envelopeOpacity)
                .zIndex(flapBehind ? 1 : 4)

            sheet
                .zIndex(2)

            EnvelopePocket()
                .fill(Color.indigo)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text("pra você")
                        .font(.custom("Noteworthy-Bold", size: 18))
                        .foregroundStyle(.white.opacity(0.9))
                        .rotationEffect(.degrees(-4))
                        .padding(.leading, 20)
                        .padding(.bottom, 16)
                }
                .frame(width: size.width, height: size.height)
                .offset(y: envelopeY)
                .opacity(envelopeOpacity)
                .allowsHitTesting(false)
                .zIndex(3)
        }
        .keyframeAnimator(initialValue: 0.0, trigger: wiggle) { view, angle in
            view.rotationEffect(.degrees(angle))
        } keyframes: { _ in
            SpringKeyframe(-5, duration: 0.11)
            SpringKeyframe(4, duration: 0.11)
            SpringKeyframe(-2, duration: 0.1)
            SpringKeyframe(0, duration: 0.18)
        }
    }

    // MARK: Carta dobrada em três

    private var sheet: some View {
        let third = Self.sheetHeight / 3
        return VStack(spacing: 0) {
            FoldPanel(angle: topFold, hinge: .bottom) {
                slice(0)
            } back: {
                PaperBack(outerEdge: .top)
            }
            .frame(height: third)
            .zIndex(3)

            slice(1)
                .frame(height: third)
                .zIndex(1)

            FoldPanel(angle: bottomFold, hinge: .top) {
                slice(2)
            } back: {
                PaperBack(outerEdge: .bottom)
            }
            .frame(height: third)
            .zIndex(2)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 22, y: 10)
        .padding(.horizontal, 16)
        .scaleEffect(sheetScale)
        .rotationEffect(.degrees(sheetTilt))
        .offset(y: sheetY + (sheetGone ? 140 : 0))
        .opacity(sheetGone ? 0 : 1)
        .contentShape(.rect)
        .onTapGesture(perform: finishWriting)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((rows + ["Tobi", postscriptText]).joined(separator: " "))
    }

    /// Um terço da carta: a carta inteira desenhada e recortada na altura da dobra.
    private func slice(_ index: Int) -> some View {
        face
            .frame(height: Self.sheetHeight)
            .offset(y: -CGFloat(index) * Self.sheetHeight / 3)
            .frame(height: Self.sheetHeight / 3, alignment: .top)
            .clipped()
    }

    /// A frente da carta aberta.
    private var face: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                InkLine(text: rows[index], ink: ink[index], isWriting: writing == index,
                        tilt: Self.tilts[index], indent: Self.indents[index])
            }
            HStack(alignment: .center, spacing: 10) {
                Text("Tobi")
                    .font(.custom("SnellRoundhand-Bold", size: 44))
                    .foregroundStyle(.indigo)
                    .mask(alignment: .leading) { InkMask(progress: ink[signature]) }
                    .overlay(alignment: .bottomLeading) {
                        Pen(isWriting: writing == signature, progress: ink[signature])
                    }
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.indigo)
                    .rotationEffect(.degrees(-14))
                    .scaleEffect(stamped ? 1 : 2.4)
                    .opacity(stamped ? 1 : 0)
                    .animation(Motion.surface, value: stamped)
            }
            .padding(.leading, 6)
            .frame(height: 58)
            InkLine(text: postscriptText, ink: ink[postscript], isWriting: writing == postscript,
                    ruled: false, color: .indigo)
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Self.paper, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            // Os vincos ficam no papel depois de aberto.
            VStack(spacing: 0) {
                Spacer()
                Crease()
                Spacer()
                Crease()
                Spacer()
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }

    // MARK: Coreografia

    private func deliver() async {
        if reduceMotion {
            arrived = true
            envelopeAway = true
            open()
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

        // Abre a aba em dois tempos, pra ela passar pra trás da carta no meio do giro.
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.easeIn(duration: 0.17)) { flap = 90 }
        try? await Task.sleep(for: .milliseconds(170))
        flapBehind = true
        withAnimation(.easeOut(duration: 0.26)) { flap = 180 }
        flips += 1

        // A carta sai meio torta, e o envelope cai enquanto ela vem pro centro.
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(Motion.surface) {
            sheetY = Self.pulledY
            sheetTilt = -4
        }
        pulls += 1
        try? await Task.sleep(for: .milliseconds(480))
        withAnimation(Motion.surface) {
            envelopeAway = true
            sheetY = 0
            sheetScale = 1
            sheetTilt = 0
        }

        // Desdobra: primeiro a de cima, depois a de baixo, e assenta.
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(Motion.surface) { topFold = 0 }
        folds += 1
        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(Motion.surface) { bottomFold = 0 }
        folds += 1
        try? await Task.sleep(for: .milliseconds(360))
        flats += 1
        tobi.mood(.attentive)

        try? await Task.sleep(for: .milliseconds(220))
        for index in rows.indices {
            guard await pen(index, text: rows[index]) else { return }
        }
        withAnimation { buttonsIn = true }
        guard await pen(signature, text: "Tobi", pace: 0.12) else { return }
        writing = nil
        stamped = true
        tobi.celebrate()
        try? await Task.sleep(for: .milliseconds(260))
        _ = await pen(postscript, text: postscriptText)
        writing = nil
    }

    /// Escreve uma linha no ritmo do texto, com a caneta riscando no dedo. Falso se a pessoa pulou.
    private func pen(_ index: Int, text: String, pace: Double = 0.024) async -> Bool {
        guard !skipped else { return false }
        writing = index
        let duration = 0.12 + Double(text.count) * pace
        withAnimation(.linear(duration: duration)) { ink[index] = 1 }
        var elapsed = 0.0
        while elapsed < duration {
            guard !skipped else { return false }
            scratches += 1
            try? await Task.sleep(for: .milliseconds(70))
            elapsed += 0.07
        }
        try? await Task.sleep(for: .milliseconds(90))
        return !skipped
    }

    /// Carta aberta e no centro, sem animação (Reduzir Movimento).
    private func open() {
        sheetY = 0
        sheetScale = 1
        sheetTilt = 0
        topFold = 0
        bottomFold = 0
        flap = 180
        flapBehind = true
    }

    private func finishWriting() {
        guard !skipped, !busy else { return }
        skipped = true
        writing = nil
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

    /// Aceitou: a carta se dobra, volta pro envelope, a aba fecha e aí o Tobi comemora.
    private func accept() {
        guard !busy else { return }
        busy = true
        skipped = true
        writing = nil
        guard !reduceMotion else { return onAccept() }
        Task {
            withAnimation(Motion.exit) { buttonsIn = false }
            withAnimation(Motion.surface) { bottomFold = -180 }
            folds += 1
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(Motion.surface) { topFold = 180 }
            folds += 1
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(Motion.surface) {
                sheetScale = Self.foldedScale
                sheetY = Self.pulledY
                sheetTilt = -4
                envelopeAway = false
            }
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(Motion.surface) {
                sheetY = Self.insideY
                sheetTilt = 0
            }
            pulls += 1
            try? await Task.sleep(for: .milliseconds(300))
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

    /// Quer ver os planos: a carta desliza pra baixo e some.
    private func leave() {
        guard !busy else { return }
        busy = true
        skipped = true
        writing = nil
        tobi.mood(.joyful)
        withAnimation(Motion.exit) {
            buttonsIn = false
            sheetGone = true
        }
        Task {
            try? await Task.sleep(for: .seconds(Motion.exitDuration))
            onBack()
        }
    }
}

// MARK: - Papel

/// Uma dobra da carta. Gira pela dobradiça e mostra o verso quando passa de 90°,
/// com sombra no vinco enquanto está inclinada.
private struct FoldPanel<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let hinge: UnitPoint
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
            back.opacity(showsBack ? 1 : 0)
        }
        .overlay {
            LinearGradient(colors: [.black.opacity(0.22 * lean), .clear],
                           startPoint: hinge, endPoint: hinge == .top ? .bottom : .top)
                .allowsHitTesting(false)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: hinge, perspective: 0.45)
    }
}

/// O verso da dobra: papel liso, arredondado só na borda de fora.
private struct PaperBack: View {
    let outerEdge: VerticalEdge

    private var shape: UnevenRoundedRectangle {
        let radius: CGFloat = 24
        return UnevenRoundedRectangle(topLeadingRadius: outerEdge == .top ? radius : 0,
                                      bottomLeadingRadius: outerEdge == .bottom ? radius : 0,
                                      bottomTrailingRadius: outerEdge == .bottom ? radius : 0,
                                      topTrailingRadius: outerEdge == .top ? radius : 0,
                                      style: .continuous)
    }

    var body: some View {
        shape
            .fill(TobiLetter.paper)
            .overlay { shape.strokeBorder(.primary.opacity(0.08)) }
    }
}

/// O vinco que fica no papel: uma sombra fina com um brilho embaixo.
private struct Crease: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.black.opacity(0.05)).frame(height: 1)
            Rectangle().fill(.white.opacity(0.5)).frame(height: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Uma linha escrita à mão no papel pautado. A tinta entra da esquerda pra direita, com a caneta na frente.
private struct InkLine: View {
    let text: String
    let ink: Double
    let isWriting: Bool
    var ruled = true
    var tilt = 0.0
    var indent: CGFloat = 0
    var color = TobiLetter.ink

    var body: some View {
        Text(text)
            .font(.custom("Noteworthy-Bold", size: 20))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .mask(alignment: .leading) { InkMask(progress: ink) }
            .overlay(alignment: .bottomLeading) { Pen(isWriting: isWriting, progress: ink) }
            .rotationEffect(.degrees(tilt), anchor: .leading)
            .padding(.leading, indent)
            .padding(.bottom, 3)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .bottomLeading)
            .overlay(alignment: .bottom) {
                if ruled {
                    Rectangle()
                        .fill(.indigo.opacity(0.14))
                        .frame(height: 1)
                }
            }
    }
}

/// A ponta da caneta na frente da tinta, tremendo um pouco como quem escreve.
private struct Pen: View {
    let isWriting: Bool
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            if isWriting {
                Image(systemName: "pencil")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(TobiLetter.ink)
                    .keyframeAnimator(initialValue: 0.0, repeating: true) { pen, lift in
                        pen.offset(y: lift)
                    } keyframes: { _ in
                        CubicKeyframe(-2.5, duration: 0.08)
                        CubicKeyframe(1, duration: 0.09)
                    }
                    .offset(x: proxy.size.width * progress - 2, y: proxy.size.height - 24)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Máscara da caneta: cheia até a ponta, com a borda macia de tinta ainda chegando.
private struct InkMask: View {
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

/// A aba triangular. Fechada mostra a patinha que lacra a carta; aberta mostra o forro.
private struct EnvelopeFlapView: View, Animatable {
    var angle: Double

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showsInside = angle > 90
        let closed = max(0, cos(angle * .pi / 180))
        ZStack {
            EnvelopeFlap()
                .fill(Color.indigo.mix(with: .white, by: 0.12))
                .overlay(alignment: .bottom) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(.bottom, 16)
                }
                .shadow(color: .black.opacity(0.22 * closed), radius: 5, y: 3)
                .opacity(showsInside ? 0 : 1)
            EnvelopeFlap()
                .fill(Color.indigo.mix(with: .black, by: 0.3))
                .overlay { PawLining() }
                .clipShape(EnvelopeFlap())
                .opacity(showsInside ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
    }
}

/// Forro de dentro do envelope: patinhas espalhadas, bem apagadas.
private struct PawLining: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(0..<9, id: \.self) { column in
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 11))
                            .rotationEffect(.degrees((row + column).isMultiple(of: 2) ? -20 : 18))
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? 0 : 16)
            }
        }
        .foregroundStyle(.white.opacity(0.1))
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A frente do envelope: o bolso com a dobra em V.
private struct EnvelopePocket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let fold = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.7)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.38))
        path.addQuadCurve(to: CGPoint(x: fold.x - 16, y: fold.y - 6),
                          control: CGPoint(x: rect.width * 0.3, y: rect.minY + rect.height * 0.58))
        path.addQuadCurve(to: CGPoint(x: fold.x + 16, y: fold.y - 6), control: fold)
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38),
                          control: CGPoint(x: rect.width * 0.7, y: rect.minY + rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A aba: triângulo com a ponta arredondada.
private struct EnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: tip.x - 22, y: tip.y - 14))
        path.addQuadCurve(to: CGPoint(x: tip.x + 22, y: tip.y - 14), control: tip)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
