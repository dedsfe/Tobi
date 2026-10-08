import SwiftUI

/// Tocou no X do paywall: chega uma carta do Tobi. O envelope treme, a aba abre, a carta sai,
/// desdobra e o Tobi escreve à mão as 24 horas de cortesia, assina e carimba a patinha.
/// Tocar na carta termina de escrever na hora.
struct TobiLetter: View {
    let onAccept: () -> Void
    let onBack: () -> Void

    private enum Phase: Int, Comparable {
        case sealed, arrived, pulled, unfolded
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    private static let hours = Int(TobiStore.freePassHours)
    private static let envelope = CGSize(width: 290, height: 184)
    static let paper = Color(light: .white, dark: Color(white: 0.16))

    @State private var phase = Phase.sealed
    @State private var flap = 0.0
    /// Passou de 90°: a aba vai pra trás da carta.
    @State private var flapBehind = false
    @State private var wiggle = 0
    @State private var ink = Array(repeating: 0.0, count: 8)
    @State private var stamped = false
    @State private var buttonsIn = false
    @State private var skipped = false
    @State private var until = Date.now.addingTimeInterval(TobiStore.freePassHours * 3600)
    /// Gatilhos dos toques: chegada, aba, papel saindo, desdobrar, caneta e carimbo.
    @State private var arrivals = 0
    @State private var bumps = 0
    @State private var flips = 0
    @State private var pulls = 0
    @State private var unfolds = 0
    @State private var scratches = 0
    @Namespace private var sheet
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

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if phase >= .arrived && phase < .unfolded {
                    envelope
                        .transition(.asymmetric(insertion: AnyTransition(.emerge),
                                                removal: .offset(y: 90).combined(with: .opacity)))
                } else if phase == .unfolded {
                    letter
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 6) {
                PaywallButton(title: "Quero minhas \(Self.hours) horas", action: onAccept)
                Button("Prefiro ver os planos", action: onBack)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
            .reveal(buttonsIn, order: 0)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: arrivals)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: bumps)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: flips)
        .sensoryFeedback(.impact(weight: .light), trigger: pulls)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: unfolds)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.3), trigger: scratches)
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .task { await deliver() }
    }

    // MARK: Envelope

    private var envelope: some View {
        let size = Self.envelope
        // Quanto a carta sobe pra fora do envelope (positivo = pra cima).
        let lift: CGFloat = phase >= .pulled ? 96 : -10
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.indigo.mix(with: .black, by: 0.3))
                .zIndex(0)

            envelopeFlap
                .zIndex(flapBehind ? 1 : 4)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Self.paper)
                .frame(width: size.width - 28, height: size.height - 20)
                .matchedGeometryEffect(id: "sheet", in: sheet)
                .alignmentGuide(.top) { _ in lift }
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
                .zIndex(3)
        }
        .frame(width: size.width, height: size.height)
        .keyframeAnimator(initialValue: 0.0, trigger: wiggle) { view, angle in
            view.rotationEffect(.degrees(angle))
        } keyframes: { _ in
            SpringKeyframe(-5, duration: 0.11)
            SpringKeyframe(4, duration: 0.11)
            SpringKeyframe(-2, duration: 0.1)
            SpringKeyframe(0, duration: 0.18)
        }
        .accessibilityElement()
        .accessibilityLabel("Uma carta do Tobi")
    }

    /// A aba triangular. Gira pra cima pela dobra e leva a patinha que lacrava a carta.
    private var envelopeFlap: some View {
        let size = Self.envelope
        return EnvelopeFlap()
            .fill(Color.indigo.mix(with: .white, by: 0.12))
            .frame(width: size.width, height: size.height * 0.6)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16, style: .continuous))
            .overlay(alignment: .bottom) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .padding(.bottom, 16)
                    .opacity(flapBehind ? 0 : 1)
            }
            .rotation3DEffect(.degrees(flap), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
    }

    // MARK: Carta

    private var letter: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                InkLine(text: rows[index], ink: ink[index])
            }
            HStack(alignment: .center, spacing: 10) {
                Text("Tobi")
                    .font(.custom("SnellRoundhand-Bold", size: 44))
                    .foregroundStyle(.indigo)
                    .mask(alignment: .leading) { InkMask(progress: ink[signature]) }
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.indigo)
                    .rotationEffect(.degrees(-14))
                    .scaleEffect(stamped ? 1 : 2.4)
                    .opacity(stamped ? 1 : 0)
                    .animation(Motion.surface, value: stamped)
            }
            .frame(height: 58)
            InkLine(text: postscriptText, ink: ink[postscript], ruled: false)
                .foregroundStyle(.indigo)
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.paper, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.07), radius: 22, y: 10)
        .matchedGeometryEffect(id: "sheet", in: sheet)
        .padding(.horizontal, 16)
        .contentShape(.rect)
        .onTapGesture(perform: finishWriting)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((rows + ["Tobi", postscriptText]).joined(separator: " "))
    }

    // MARK: Coreografia

    private func deliver() async {
        if reduceMotion {
            phase = .unfolded
            finishWriting()
            return
        }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(Motion.surface) { phase = .arrived }
        arrivals += 1

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

        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(Motion.surface) { phase = .pulled }
        pulls += 1

        try? await Task.sleep(for: .milliseconds(520))
        withAnimation(Motion.surface) { phase = .unfolded }
        unfolds += 1
        tobi.acknowledge()

        try? await Task.sleep(for: .milliseconds(450))
        for index in rows.indices {
            guard await pen(index, text: rows[index]) else { return }
        }
        withAnimation { buttonsIn = true }
        guard await pen(signature, text: "Tobi", pace: 0.12) else { return }
        stamped = true
        tobi.acknowledge()
        try? await Task.sleep(for: .milliseconds(260))
        _ = await pen(postscript, text: postscriptText)
    }

    /// Escreve uma linha no ritmo do texto, com a caneta riscando no dedo. Falso se a pessoa pulou.
    private func pen(_ index: Int, text: String, pace: Double = 0.024) async -> Bool {
        guard !skipped else { return false }
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

    private func finishWriting() {
        guard !skipped else { return }
        skipped = true
        withAnimation(Motion.quick) {
            ink = ink.map { _ in 1 }
            buttonsIn = true
        }
        stamped = true
    }
}

// MARK: - Peças

/// Uma linha escrita à mão no papel pautado. A tinta entra da esquerda pra direita.
private struct InkLine: View {
    let text: String
    let ink: Double
    var ruled = true

    var body: some View {
        Text(text)
            .font(.custom("Noteworthy-Bold", size: 20))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .mask(alignment: .leading) { InkMask(progress: ink) }
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
