import SwiftUI

/// O motion do Tobi inteiro sai daqui. Regra: superfície nova *emerge* de onde foi tocada
/// e o conteúdo dela se *revela* em cascata. Nada de animação solta fora destes tokens.
enum Motion {
    /// Abrir e fechar superfícies: cards, barras que viram outra coisa, sheets custom.
    static let surface = Animation.spring(duration: 0.55, bounce: 0.24)
    /// Resposta a toque, números mudando, estados pequenos.
    static let quick = Animation.spring(duration: 0.3, bounce: 0.15)
    /// Idle do Tobi: respiração lenta, sem quicar entre as poses.
    static let tobiIdle = Animation.easeInOut(duration: 1.6)
    /// Respiração calma (um ciclo) e ofegante, como cachorro: rápida, curta, com a língua pra fora.
    static let tobiBreathPeriod = 2.6
    static let tobiPantPeriod = 0.34
    static let tobiPantRest = 1.4...3.0
    static let tobiPantDuration = 3.5...6.0
    static let tobiEarRest = 4.0...9.0
    static let tobiEarDuration = 0.8...1.3
    static let tobiBlinkClose = 0.10
    static let tobiBlinkHold = 0.04
    static let tobiBlinkOpen = 0.16
    static let tobiBlinkInterval = 3.2...5.4
    static let tobiLookDuration = 2.4
    static let tobiFirstLook = 7.0
    static let tobiLookInterval = 8.0...12.0
    /// Depois que o dedo sai, o Tobi ainda olha pro lugar um tempinho antes de voltar ao idle.
    static let tobiFollowHold = 0.7
    /// Manias (bocejo, espirro, se distrair): a primeira vem cedo, depois uma a cada tanto.
    static let tobiFirstQuirk = 9.0
    static let tobiQuirkRest = 12.0...24.0
    /// Lambidas rápidas nos beiços, por conta da língua.
    static let tobiLickRest = 5.0...11.0
    /// Intervalo entre itens de uma cascata.
    static let stagger = 0.04
    /// Saída do conteúdo: rápida e junta, pra casca poder fechar logo depois.
    static let exit = Animation.spring(duration: 0.2, bounce: 0)
    static let exitDuration = 0.16

    /// Animação de um item da cascata, já com o atraso da posição dele.
    static func cascade(_ order: Int) -> Animation {
        surface.delay(Double(order) * stagger)
    }

    /// Fecha uma superfície em dois tempos: primeiro o conteúdo some, depois a casca.
    @MainActor
    static func close(content: () -> Void, surface closeSurface: @escaping @MainActor () -> Void) {
        withAnimation(exit, content)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(exitDuration))
            withAnimation(surface, closeSurface)
        }
    }
}

/// Mantém o emoji original; só a pose do palco muda. Usado primeiro no laboratório.
struct TobiIdleStage: View {
    var isPlaying = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if isPlaying && !reduceMotion && scenePhase == .active {
            TobiStage()
                .phaseAnimator([0.0, 1.0, 0.0, -1.0]) { stage, phase in
                    stage
                        .scaleEffect(1 + phase * 0.012)
                        .rotationEffect(.degrees(phase * 1.5))
                        .offset(y: phase * -1.5)
                } animation: { _ in
                    Motion.tobiIdle
                }
        } else {
            TobiStage()
        }
    }
}

// MARK: - Emerge

/// Superfície que nasce do ponto de origem (por padrão, de baixo): cresce, sobe e ganha foco.
struct EmergeTransition: Transition {
    var anchor: UnitPoint = .bottom

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(EmergeEffect(isVisible: phase.isIdentity, anchor: anchor))
    }
}

private struct EmergeEffect: ViewModifier {
    let isVisible: Bool
    let anchor: UnitPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(isVisible ? 1 : 0)
        } else {
            content
                .opacity(isVisible ? 1 : 0)
                .blur(radius: isVisible ? 0 : 12)
                .scaleEffect(isVisible ? 1 : 0.82, anchor: anchor)
                .offset(y: isVisible ? 0 : (anchor == .top ? -16 : 16))
        }
    }
}

extension Transition where Self == EmergeTransition {
    static var emerge: EmergeTransition { EmergeTransition() }
    static func emerge(from anchor: UnitPoint) -> EmergeTransition { EmergeTransition(anchor: anchor) }
}

// MARK: - Reveal

extension View {
    /// Conteúdo de uma superfície que entra em cascata: `order` define a vez de cada item.
    func reveal(_ isVisible: Bool, order: Int) -> some View {
        modifier(RevealEffect(isVisible: isVisible, order: order))
    }
}

private struct RevealEffect: ViewModifier {
    let isVisible: Bool
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible || reduceMotion ? 0 : 6)
            .offset(y: isVisible || reduceMotion ? 0 : 10)
            .animation(isVisible ? Motion.cascade(order) : Motion.exit, value: isVisible)
    }
}


/// Independent, seeded gesture clocks. All channels settle before their next gesture.
/// The seed makes the same idle reproducible in tests without affecting the renderer.
struct TobiIdleBehavior {
    /// Estados do onboarding (design/tobi-character/onboarding-states.md). Cada um muda só a
    /// intensidade dos canais; os relógios continuam e a troca é interpolada.
    enum Mood: CaseIterable {
        case joyful, attentive, curious, presenting
        /// Passageiro: comemora uma vez e passa sozinho para `presenting`.
        case celebrating
    }

    struct Pose {
        var breath: Float = 0
        var blink: Float = 0
        var cheer: Float = 0.12
        var gazeX: Float = 0
        var gazeY: Float = 0
        var headYaw: Float = 0
        var headRoll: Float = 0
        /// Positivo inclina o rosto para baixo, na direção do conteúdo embaixo do palco.
        var headPitch: Float = 0
        /// Sobe e desce o rosto inteiro: respiração, ofegar e pulinhos.
        var lift: Float = 0
        var leftEar: Float = 0
        var rightEar: Float = 0
        var tonguePitch: Float = 0
        var tongueStretch: Float = 1
        /// A língua pendurada balança de lado, atrasada atrás da cabeça.
        var tongueSway: Float = 0
        /// 0 é o sorriso fechado; 1 é a boca aberta do bocejo.
        var mouthOpen: Float = 0
        /// A ponta da língua enrola pra cima (lambida).
        var tongueCurl: Float = 0
        /// 1 é a língua toda pra dentro da boca (bocejo).
        var tongueRetract: Float = 0
        /// Dobra da parte de baixo de cada orelha: positivo abana pra fora, negativo encolhe.
        var leftEarBend: Float = 0
        var rightEarBend: Float = 0
        /// Olhos um pouco mais abertos: atenção.
        var eyeWiden: Float = 0
    }

    /// Manias que aparecem sozinhas quando ninguém está mexendo nele.
    enum Quirk: CaseIterable {
        case yawn, sneeze, distraction

        var duration: Double {
            switch self {
            case .yawn: 3.0
            case .sneeze: 1.6
            case .distraction: 3.0
            }
        }
    }

    /// Intensidade de cada canal num estado. Os estados precisam ser lidos de longe:
    /// alegre ofega com a língua pra fora, atento foca o olhar e inclina o rosto,
    /// curioso inclina a cabeça de verdade.
    struct Profile {
        var cheer: Float = 0.16
        /// Força das crises de ofegar (respiração rápida, língua pra fora pulando).
        var pant: Float = 1
        /// Comprimento da língua em repouso: menos de 1 é a boca quase fechada.
        var tongueOut: Float = 1
        /// Profundidade da respiração calma.
        var breath: Float = 1
        /// Quanto a cabeça acompanha o olhar.
        var head: Float = 1
        var reach: Float = 1
        /// Inclinação de base da cabeça.
        var tilt: Float = 0
        /// Orelhas levantadas para fora, cada uma por conta.
        var perkLeft: Float = 0.02
        var perkRight: Float = 0.02
        /// Atraso da cabeça atrás dos olhos e das orelhas atrás da cabeça, em segundos.
        var headDelay: Float = 0.16
        var earLag: Float = 0.08
        /// Balanço feliz da cabeça, como quem abana o rabo.
        var wag: Float = 0.3
        /// Inclinação de cachorro curioso, trocando de lado de tempos em tempos.
        var cock: Float = 0
        var widen: Float = 0
        /// Queixo erguido (negativo) ou baixo.
        var chin: Float = 0
        var lookInterval = Motion.tobiLookInterval
        var pantRest = Motion.tobiPantRest
        var pantDuration = Motion.tobiPantDuration

        init(_ mood: Mood) {
            switch mood {
            case .joyful:
                break
            case .attentive:
                // Atenção suave no rosto: olhos focados e uma pequena inclinação.
                cheer = 0.02; pant = 0.3; tongueOut = 0.75; breath = 0.7
                head = 0.65; reach = 0.8; perkLeft = 0; perkRight = 0
                wag = 0; cock = 0.06; widen = 1; chin = -0.015
                headDelay = 0.2; earLag = 0.12
                lookInterval = 6.0...9.0; pantRest = 5.0...9.0; pantDuration = 1.4...2.4
            case .curious:
                cheer = 0.05; pant = 0.25; tongueOut = 0.85; breath = 0.8
                head = 1.2; reach = 1.05; perkLeft = 0.03; perkRight = 0.03
                wag = 0; cock = 0.24; widen = 0.4
                headDelay = 0.32; earLag = 0.3
                lookInterval = 4.5...7.0; pantRest = 4.0...7.0; pantDuration = 1.2...2.0
            case .presenting:
                cheer = 0.2; pant = 0.85; head = 0.8; reach = 0.9; perkLeft = 0.04; perkRight = 0.04
                wag = 1
                headDelay = 0.18; earLag = 0.12
                pantRest = 1.8...3.5; pantDuration = 3.0...5.0
            case .celebrating:
                cheer = 0.28; tongueOut = 1.06; breath = 1.1; perkLeft = 0.1; perkRight = 0.1
                wag = 1.4
                earLag = 0.1
                pantRest = 0.6...1.2; pantDuration = 4.0...6.0
            }
        }

        /// Caminha `amount` em direção a `target`. Os intervalos dos relógios trocam de uma vez:
        /// só valem para o próximo gesto, então não saltam.
        func blended(toward target: Profile, _ amount: Float) -> Profile {
            func mix(_ a: KeyPath<Profile, Float>) -> Float { self[keyPath: a] + (target[keyPath: a]-self[keyPath: a])*amount }
            var next = target
            for key in [\Profile.cheer, \.pant, \.tongueOut, \.breath, \.head, \.reach, \.tilt,
                        \.perkLeft, \.perkRight, \.headDelay, \.earLag, \.wag, \.cock, \.widen, \.chin]
                    as [WritableKeyPath<Profile, Float>] {
                next[keyPath: key] = mix(key)
            }
            return next
        }
    }

    /// Gesto pontual que sobe, segura e volta. Disparar de novo ou cancelar parte do nível atual,
    /// então o canal nunca salta.
    private struct Pulse {
        let attack: Double
        let hold: Double
        let release: Double
        private var start = -Double.infinity
        private var origin = 0.0
        private var fadeStart: Double?
        private var fadeFrom = 0.0

        init(attack: Double, hold: Double, release: Double) {
            self.attack = attack; self.hold = hold; self.release = release
        }

        func level(at time: Double) -> Double {
            if let fadeStart { return fadeFrom * (1 - TobiIdleBehavior.ease((time-fadeStart)/0.35)) }
            let age = time - start
            if age < 0 { return origin }
            if age < attack { return origin + (1-origin)*TobiIdleBehavior.ease(age/attack) }
            if age < attack + hold { return 1 }
            return 1 - TobiIdleBehavior.ease((age-attack-hold)/release)
        }

        /// Tempo desde o início, para a fase das oscilações. Continua correndo durante o cancelamento.
        func age(at time: Double) -> Double {
            start.isFinite ? max(0, time - start) : 0
        }

        mutating func trigger(at time: Double, delay: Double = 0) {
            origin = level(at: time)
            fadeStart = nil
            start = time + delay
        }

        mutating func cancel(at time: Double) {
            fadeFrom = level(at: time)
            fadeStart = time
        }
    }

    /// Mola com massa: segue o alvo, passa um pouco e volta. Dá peso à língua e à virada do arrasto.
    private struct Spring {
        var value: Float = 0
        var velocity: Float = 0
        mutating func step(toward target: Float, dt: Double, frequency: Float, damping: Float) {
            let omega = 2 * Float.pi * frequency
            var left = Float(min(dt, 0.25))
            while left > 0 {
                let h = min(left, 1/240)
                velocity += (omega*omega*(target-value) - 2*damping*omega*velocity)*h
                value += velocity*h
                left -= h
            }
        }
    }

    private struct Random: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2685821657736338717
        }
    }
    private struct Gesture {
        var start: Double
        var duration: Double
        var strength: Double = 1
        var age: Double = -1
        mutating func advance(_ time: Double, rest: ClosedRange<Double>,
                              duration: ClosedRange<Double>, random: inout Random) {
            if time >= start + self.duration {
                start = time + Double.random(in: rest, using: &random)
                self.duration = Double.random(in: duration, using: &random)
                strength = Double.random(in: 0.7...1, using: &random)
            }
            age = time - start
        }
        var envelope: Double {
            guard age > 0, age < duration else { return 0 }
            return TobiIdleBehavior.ease(age/0.3) * TobiIdleBehavior.ease((duration-age)/0.55)
        }
        var twitch: Float {
            guard age > 0, age < duration else { return 0 }
            let t = age/duration
            return Float(strength * sin(t * .pi * 3) * exp(-2*t) * pow(sin(t * .pi), 2))
        }
    }

    /// Um sorteio por parte: mexer no relógio de uma não muda a sequência das outras.
    private var random: Random
    private var earRandom: Random
    private var pantRandom: Random
    private var lookRandom: Random
    private var left = Gesture(start: 1.8, duration: 1.1)
    private var right = Gesture(start: 3.9, duration: 0.95)
    private var pant = Gesture(start: 0.9, duration: 3.5)
    private var look = Gesture(start: Motion.tobiFirstLook, duration: Motion.tobiLookDuration)
    private var lookX: Float = -0.024
    private var lookY: Float = 0.005
    private var blinkStart: Double = -1
    private var nextBlink = Motion.tobiBlinkInterval.lowerBound
    private var secondBlink = false
    private var tapBlinkStart: Double = -1

    private(set) var mood = Mood.joyful
    private var profile = Profile(.joyful)
    private var lastTime: Double?
    /// Fase integrada da respiração: acelera ao ofegar sem pular de lugar.
    private var breathPhase = 0.0
    /// Inclinação que as orelhas seguem, com o atraso do estado.
    private var earRoll: Float = 0
    private var welcome = Pulse(attack: 0.55, hold: 0.5, release: 0.8)
    private var acknowledgement = Pulse(attack: 0.16, hold: 0.1, release: 0.5)
    private var presentEyes = Pulse(attack: 0.4, hold: 0.75, release: 0.65)
    private var presentHead = Pulse(attack: 0.5, hold: 0.6, release: 0.7)
    private var celebration = Pulse(attack: 0.25, hold: 0.85, release: 0.7)
    private var petting = Pulse(attack: 0.22, hold: 0.55, release: 0.6)
    /// Fase própria do carinho: só anda enquanto ele está no ar, então tocar de novo não pula.
    private var petPhase = 0.0
    private var petCount = 0
    private var delighted = Pulse(attack: 0.22, hold: 1.0, release: 0.7)
    /// Quando a comemoração passa a vez para `presenting`.
    private var handoff: Double?
    /// Último lugar do dedo em relação ao rosto (x pra direita, y pra cima, até 1) e se ele ainda está na tela.
    private var finger: SIMD2<Float>?
    private var touching = false
    private var released = -Double.infinity
    /// Os olhos acham o dedo primeiro; a cabeça vem atrás, com o atraso do estado.
    private var eyeTarget = SIMD2<Float>(0, 0)
    private var headTarget = SIMD2<Float>(0, 0)
    private var focus: Float = 0
    /// Velocidade do arrasto na horizontal, em larguras de tela por segundo, e a virada que ela causa.
    private var swipe: Float = 0
    private var swipeLevel: Float = 0
    private var swing = Spring()
    private var tongueSwing = Spring()
    private var lastYaw: Float?
    private var tongueRandom: Random
    private var lick = Gesture(start: 5.5, duration: 0.8)
    private var quirkRandom: Random
    private(set) var quirk: Quirk?
    /// Desligado, as manias só acontecem quando pedidas: o laboratório mostra uma de cada vez.
    var spontaneous = true
    private var quirkStart = 0.0
    private var quirkSide: Float = 1
    private var nextQuirk = Motion.tobiFirstQuirk
    /// O espirro conta quando sai, para o palco soltar as gotinhas uma vez.
    private(set) var sneezes = 0
    private var sprayed = false
    private var cockRandom: Random
    private var cock = Spring()
    private var cockSide: Float = 1
    private var nextCock = 0.0
    private var wagPhase = 0.0
    private var nextShow = Double.infinity
    private var leftBend = Spring()
    private var rightBend = Spring()
    private var lastEars: (left: Float, right: Float, roll: Float, lift: Float)?
    private var bendPull = SIMD2<Float>(0, 0)

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        random = Random(state: max(1, seed))
        earRandom = Random(state: max(1, seed &* 0x9E3779B97F4A7C15))
        pantRandom = Random(state: max(1, seed ^ 0xD1B54A32D192ED03))
        lookRandom = Random(state: max(1, (seed &+ 0x632BE59BD9B4E019) &* 3))
        tongueRandom = Random(state: max(1, seed &* 0xBF58476D1CE4E5B9 &+ 7))
        quirkRandom = Random(state: max(1, (seed ^ 0x94D049BB133111EB) &+ 11))
        cockRandom = Random(state: max(1, (seed &+ 0x2545F4914F6CDD1D) ^ 0x5851F42D4C957F2D))
    }

    /// Troca de estado. Os gestos da tela anterior se desfazem a partir de onde estão.
    /// `entering` toca o gesto de entrada; ao voltar uma tela, o estado só é recuperado
    /// e a comemoração vira apresentação.
    mutating func setMood(_ next: Mood, at time: Double, entering: Bool) {
        for index in 0..<5 { cancelPulse(index, at: time) }
        petCount = 0
        handoff = nil
        nextShow = next == .presenting || next == .celebrating ? time + 4.5 : .infinity
        mood = next == .celebrating && !entering ? .presenting : next
        guard entering else { return }
        switch mood {
        case .joyful:
            welcome.trigger(at: time, delay: 0.3)
        case .attentive:
            break
        case .curious:
            lookSoon(at: time + 0.45)
        case .presenting:
            present(at: time + 0.2)
            nextShow = time + 4.5
        case .celebrating:
            celebration.trigger(at: time, delay: 0.15)
            handoff = time + 0.15 + celebration.attack + celebration.hold*0.7
        }
    }

    /// Confirma um toque: a mesma piscada e inclinação discreta para qualquer opção.
    mutating func acknowledge(at time: Double) {
        acknowledgement.trigger(at: time)
        pantNow(at: time)
        // A piscada do toque corre por fora da agenda do idle, que segue intacta.
        // Uma já em curso confirma sozinha; recomeçar abriria o olho de uma vez.
        let duration = Motion.tobiBlinkClose + Motion.tobiBlinkHold + Motion.tobiBlinkOpen
        guard tapBlinkStart < 0 || time - tapBlinkStart >= duration else { return }
        tapBlinkStart = time
    }

    /// Carinho simples: rostinho inclinado e olhos de contente. Cada terceiro carinho prolonga a expressão feliz.
    mutating func pet(at time: Double) {
        petting.trigger(at: time)
        petCount += 1
        if petCount == 3 {
            petCount = 0
            delighted.trigger(at: time)
        }
    }

    /// Segue o dedo na tela. `nil` quando ele sai: o Tobi segura o olhar um instante e volta ao idle.
    /// `swipe` é a velocidade do arrasto na horizontal (larguras de tela por segundo):
    /// puxar pra um lado faz ele dar uma viradinha pra esse lado.
    mutating func follow(_ point: SIMD2<Float>?, swipe: Float = 0, at time: Double) {
        guard let point else {
            if touching { released = time }
            touching = false
            self.swipe = 0
            return
        }
        finger = point.clamped(lowerBound: SIMD2(-1, -1), upperBound: SIMD2(1, 1))
        touching = true
        self.swipe = swipe.isFinite ? min(6, max(-6, swipe)) : 0
    }

    /// Toca uma mania agora. Uma que já está no ar termina primeiro, para não pular.
    mutating func perform(_ next: Quirk, at time: Double) {
        guard quirk == nil || time - quirkStart >= quirk!.duration else { return }
        quirk = next
        sprayed = false
        quirkStart = time
        quirkSide = Bool.random(using: &quirkRandom) ? 1 : -1
        nextQuirk = max(nextQuirk, time + next.duration + Motion.tobiQuirkRest.lowerBound)
    }

    /// Lambe os beiços agora, se a língua não estiver no meio de uma lambida.
    mutating func lickNow(at time: Double) {
        guard lick.age <= 0 || lick.age >= lick.duration || lick.start > time else { return }
        lick.start = time
        lick.duration = 0.8
        lick.strength = 1
    }

    /// Começa uma crise de ofegar agora, sem cortar uma que já está acontecendo.
    private mutating func pantNow(at time: Double) {
        guard pant.age <= 0 || pant.age >= pant.duration || pant.start > time else { return }
        pant.start = time + 0.05
        let range = Profile(mood).pantDuration
        pant.duration = (range.lowerBound + range.upperBound)/2
        pant.strength = 1
    }

    /// Expressão parada de cada estado, para Movimento Reduzido e segundo plano.
    static func still(_ mood: Mood) -> Pose {
        let profile = Profile(mood)
        var pose = Pose()
        pose.cheer = profile.cheer
        pose.headRoll = profile.tilt + profile.cock
        pose.headPitch = profile.chin
        pose.eyeWiden = profile.widen
        pose.tongueStretch = profile.tongueOut
        pose.leftEar = earLimits(left: -profile.perkLeft - (profile.tilt+profile.cock)*0.5)
        pose.rightEar = earLimits(right: profile.perkRight - (profile.tilt+profile.cock)*0.55 + profile.cock*0.45)
        return pose
    }

    private mutating func cancelPulse(_ index: Int, at time: Double) {
        switch index {
        case 0: welcome.cancel(at: time)
        case 1: acknowledgement.cancel(at: time)
        case 2: presentEyes.cancel(at: time)
        case 3: presentHead.cancel(at: time)
        default: celebration.cancel(at: time)
        }
    }

    private mutating func present(at time: Double) {
        presentEyes.trigger(at: time)
        // A cabeça acompanha os olhos com atraso.
        presentHead.trigger(at: time, delay: 0.15)
    }

    /// Antecipa o próximo olhar, sem interromper um que já está no ar.
    private mutating func lookSoon(at time: Double) {
        guard look.age <= 0 || look.age >= look.duration, look.start > time else { return }
        pickLookTarget()
        look.start = time
    }

    private mutating func pickLookTarget() {
        lookX = Float.random(in: 0.017...0.027, using: &lookRandom) * (Bool.random(using: &lookRandom) ? 1 : -1)
        lookY = Float.random(in: -0.004...0.009, using: &lookRandom)
    }

    private struct QuirkPose {
        var eyes: Float = 0, gazeX: Float = 0, gazeY: Float = 0
        /// Quanto a cabeça troca o olhar do idle pelo da mania, e para onde.
        var head: Float = 0, headYaw: Float = 0
        var yaw: Float = 0, roll: Float = 0, pitch: Float = 0, lift: Float = 0
        var blink: Float = 0, cheer: Float = 0, mouth: Float = 0
        var leftEar: Float = 0, rightEar: Float = 0
        var tongueStretch: Float = 0, tonguePitch: Float = 0
        var retract: Float = 0
    }

    /// Forma de cada mania no tempo. `weight` some quando o dedo chega, então tocar desfaz a mania sem salto.
    private func quirkOffsets(at time: Double, weight: Float) -> QuirkPose {
        var out = QuirkPose()
        guard let quirk, weight > 0 else { return out }
        let t = time - quirkStart, d = quirk.duration
        func e(_ x: Double) -> Float { Float(Self.ease(x)) }
        switch quirk {
        case .yawn:
            // A língua entra primeiro; aí o focinho sobe, os olhos fecham e a boca abre devagar.
            // Fecha a boca, a língua volta e ele estala os beiços (lambida no fim).
            out.retract = e((t-0.05)/0.45) * e((d-0.1-t)/0.5)
            let open = e((t-0.4)/0.75) * e((d-0.3-t)/0.6)
            let stretch = e((t-0.2)/0.6) * e((d-0.2-t)/0.8)
            out.pitch = -0.09*stretch; out.lift = 0.014*stretch; out.roll = quirkSide*0.05*stretch
            out.cheer = 0.62*stretch; out.mouth = open
            out.leftEar = 0.05*stretch; out.rightEar = -0.05*stretch
        case .sneeze:
            // "Ah... ah...": cabeça pra trás e olhos apertando; "tchim": cabeça pra frente,
            // orelhas abanam; depois uma sacudida.
            let build = e(t/0.75), snap = e((t-0.75)/0.2), recover = e((t-0.95)/0.6)
            let windUp = build*(1-snap), hit = snap*(1-recover)
            out.pitch = -0.07*windUp + 0.09*hit
            out.lift = 0.015*windUp - 0.012*hit
            out.cheer = (0.45*build + 0.15*snap)*(1-recover)
            out.mouth = 0.4*windUp
            out.retract = 0.6*windUp
            out.leftEar = -0.1*hit; out.rightEar = 0.1*hit
            let shake = e((t-0.95)/0.08) * (1-e((t-1.3)/0.25))
            out.yaw = 0.05*Float(sin((t-0.95) * 2 * .pi/0.26))*shake
        case .distraction:
            // Algo chamou atenção do lado: olhos primeiro, cabeça inclinada, orelha daquele lado em pé.
            // Volta com uma piscada.
            let eyes = e(t/0.2) * e((d-0.3-t)/0.35)
            let head = e((t-0.12)/0.5) * e((d-0.35-t)/0.6)
            out.eyes = eyes
            out.gazeX = quirkSide*0.027; out.gazeY = 0.007
            out.head = head; out.headYaw = quirkSide*0.15; out.roll = quirkSide*0.09*head; out.pitch = -0.03*head
            if quirkSide < 0 { out.leftEar = -0.05*head } else { out.rightEar = 0.05*head }
            out.blink = Self.blinkClosure(age: t-(d-0.55))
        }
        out.eyes *= weight; out.head *= weight; out.yaw *= weight; out.roll *= weight; out.pitch *= weight; out.lift *= weight
        out.blink *= weight; out.cheer *= weight; out.mouth *= weight
        out.leftEar *= weight; out.rightEar *= weight
        out.tongueStretch *= weight; out.tonguePitch *= weight; out.retract *= weight
        return out
    }

    static func ease(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t*t*(3-2*t)
    }

    static func blinkClosure(age: Double) -> Float {
        guard age >= 0 else { return 0 }
        let holdEnd = Motion.tobiBlinkClose + Motion.tobiBlinkHold
        if age < Motion.tobiBlinkClose { return Float(ease(age/Motion.tobiBlinkClose)) }
        if age < holdEnd { return 1 }
        return Float(1-ease((age-holdEnd)/Motion.tobiBlinkOpen))
    }

    /// As orelhas abrem bastante para fora, mas quase nada para dentro, onde encostariam no rosto.
    static func earLimits(left angle: Float) -> Float { min(0.1, max(-0.32, angle)) }
    static func earLimits(right angle: Float) -> Float { min(0.32, max(-0.1, angle)) }

    mutating func sample(at time: Double) -> Pose {
        if let handoff, time >= handoff {
            self.handoff = nil
            mood = .presenting
            present(at: time)
            nextShow = time + 4.5
        }
        // Apresentando, ele volta a mostrar o cartão de tempos em tempos, como quem diz "olha isso".
        if mood == .presenting, time >= nextShow {
            if !touching { present(at: time) }
            nextShow = time + Double.random(in: 4.5...7.0, using: &lookRandom)
        }
        let target = Profile(mood)
        let dt = lastTime.map { max(0, time-$0) } ?? 0
        profile = lastTime == nil ? target : profile.blended(toward: target, Float(1 - exp(-dt/0.45)))
        left.advance(time, rest: Motion.tobiEarRest, duration: Motion.tobiEarDuration, random: &earRandom)
        right.advance(time, rest: Motion.tobiEarRest, duration: Motion.tobiEarDuration, random: &earRandom)
        pant.advance(time, rest: profile.pantRest, duration: profile.pantDuration, random: &pantRandom)
        if time >= look.start + look.duration {
            pickLookTarget()
        }
        look.advance(time, rest: profile.lookInterval, duration: 2.4...3.2, random: &lookRandom)
        lick.advance(time, rest: Motion.tobiLickRest, duration: 0.7...0.9, random: &tongueRandom)
        if let quirk, time - quirkStart >= quirk.duration {
            self.quirk = nil
            // Depois do bocejo, estala os beiços.
            if quirk == .yawn { lickNow(at: time) }
        }
        if quirk == .sneeze, !sprayed, time - quirkStart >= 0.82 {
            sprayed = true
            sneezes += 1
        }
        if quirk == nil, time >= nextQuirk {
            // Ninguém interrompe: com dedo na tela, comemoração ou carinho, a mania espera.
            if !spontaneous || touching || focus > 0.01 || mood == .celebrating || handoff != nil || petting.level(at: time) > 0 || delighted.level(at: time) > 0 {
                nextQuirk = time + 2
            } else {
                let pick = Double.random(in: 0..<1, using: &quirkRandom)
                let next: Quirk = pick < 0.45 ? .distraction : pick < 0.75 ? .yawn : .sneeze
                quirk = next
                sprayed = false
                quirkSide = Bool.random(using: &quirkRandom) ? 1 : -1
                quirkStart = time
                nextQuirk = time + next.duration + Double.random(in: Motion.tobiQuirkRest, using: &quirkRandom)
            }
        }
        if time >= nextBlink {
            blinkStart = time
            let duration = Motion.tobiBlinkClose + Motion.tobiBlinkHold + Motion.tobiBlinkOpen
            if !secondBlink && Double.random(in: 0...1, using: &random) < 0.18 {
                secondBlink = true
                nextBlink = time + duration + Double.random(in: 0.16...0.24, using: &random)
            } else {
                secondBlink = false
                nextBlink = time + duration + Double.random(in: Motion.tobiBlinkInterval, using: &random)
            }
        }
        var pose = Pose()
        pose.blink = blinkStart >= 0 ? Self.blinkClosure(age: time-blinkStart) : 0
        if tapBlinkStart >= 0 { pose.blink = max(pose.blink, Self.blinkClosure(age: time-tapBlinkStart)) }

        let cheering = Float(celebration.level(at: time))
        let cheerAge = celebration.age(at: time)
        // The soft face gesture quiets the panting; a scratch does not force a pant or a hop.
        let petted = Float(petting.level(at: time))
        let happy = max(petted, Float(delighted.level(at: time)))
        let panting = max(Float(pant.envelope*pant.strength)*profile.pant, cheering)*(1-petted)
        let period = Motion.tobiBreathPeriod + (Motion.tobiPantPeriod-Motion.tobiBreathPeriod)*Double(panting)
        breathPhase += dt*2 * .pi/period
        let wave = Float(sin(breathPhase))
        pose.breath = wave * (profile.breath*(1-panting) + 0.6*panting)

        // The glance at the card below replaces the idle look while it lasts.
        let glance = Float(presentEyes.level(at: time))
        let nod = Float(presentHead.level(at: time))
        let attention = Float(look.envelope) * (1-glance)
        // Eyes find the target first; the head follows, holds, then returns.
        let headAttention = Float(Self.ease((look.age-Double(profile.headDelay))/0.5)
                                  * Self.ease((look.duration-look.age)/0.7)) * profile.head * (1-nod)
        pose.gazeX = lookX*profile.reach*attention
        pose.gazeY = lookY*profile.reach*attention - 0.009*glance
        pose.headYaw = lookX*3*headAttention
        // Each pant nods the head a little: the breath pushes it, the chin follows.
        pose.headPitch = 0.055*nod + panting*0.022*(0.5 + 0.5*wave)

        // A finger on screen wins over the idle look: eyes snap to it, the head trails behind.
        if let finger {
            eyeTarget += (finger-eyeTarget) * (1 - exp(-Float(dt)/0.05))
            headTarget += (finger-headTarget) * (1 - exp(-Float(dt)/(0.12 + profile.headDelay)))
        }
        let wanted: Float = finger != nil && (touching || time - released < Motion.tobiFollowHold) ? 1 : 0
        focus += (wanted-focus) * (1 - exp(-Float(dt)/(wanted > focus ? 0.12 : 0.45)))
        let follow = Float(Self.ease(Double(focus)))*(1-petted)
        pose.gazeX += (eyeTarget.x*0.027 - pose.gazeX)*follow
        pose.gazeY += (eyeTarget.y*0.01 - pose.gazeY)*follow
        pose.headYaw += (headTarget.x*0.2 - pose.headYaw)*follow
        pose.headPitch += min(0.12, max(-0.07, -headTarget.y*0.12))*follow
        let hop = cheering * Float(pow(sin(cheerAge * .pi/0.38), 2))
        pose.lift = (pose.breath*0.012 + panting*0.014*wave) + hop*0.045
        let greeting = Float(welcome.level(at: time))
        let tap = Float(acknowledgement.level(at: time))
        if petted > 0 { petPhase += dt*2 * .pi/1.1 }
        let wiggle = petted * Float(sin(petPhase))
        pose.headRoll = pose.breath*0.012*(1-panting) + lookX*2.4*headAttention*(1-follow) + profile.tilt
            + greeting*0.12 + tap*0.06 + wiggle*0.08 + headTarget.x*0.07*follow
        pose.headPitch += petted*0.025

        // Dragging turns him toward the pull, with a little overshoot when the finger stops.
        swipeLevel += ((touching ? swipe : 0) - swipeLevel) * (1 - exp(-Float(dt)/0.08))
        swing.step(toward: min(0.22, max(-0.22, swipeLevel*0.12)), dt: dt, frequency: 1.5, damping: 0.5)
        pose.headYaw += swing.value
        pose.headRoll += swing.value*0.45

        // Curious: a real dog head tilt that switches sides now and then, overshooting a little.
        if profile.cock > 0.01, time >= nextCock {
            cockSide = -cockSide
            nextCock = time + Double.random(in: 2.2...3.8, using: &cockRandom)
        }
        cock.step(toward: cockSide*profile.cock*(1-follow), dt: dt, frequency: 1.1, damping: 0.55)
        pose.headRoll += cock.value
        // Happy sway, like a wagging tail moving the whole dog.
        wagPhase += dt*2 * .pi/0.85
        pose.headRoll += profile.wag*0.035*Float(sin(wagPhase))
        pose.lift += profile.wag*0.005*Float(pow(sin(wagPhase), 2))
        pose.headPitch += profile.chin

        let quirkPose = quirkOffsets(at: time, weight: (1-follow)*(1-petted))
        pose.gazeX += (quirkPose.gazeX - pose.gazeX)*quirkPose.eyes
        pose.gazeY += (quirkPose.gazeY - pose.gazeY)*quirkPose.eyes
        pose.headYaw += (quirkPose.headYaw - pose.headYaw)*quirkPose.head + quirkPose.yaw
        pose.headRoll += quirkPose.roll
        pose.headPitch += quirkPose.pitch
        pose.lift += quirkPose.lift
        pose.blink = max(pose.blink, quirkPose.blink)
        pose.mouthOpen = quirkPose.mouth

        // Ears trail the head by the mood's lag, each with its own rhythm, and jiggle with the pants.
        if lastTime != nil, profile.earLag > 0 {
            earRoll += (pose.headRoll-earRoll) * (1 - exp(-Float(dt)/profile.earLag))
        } else {
            earRoll = pose.headRoll
        }
        let calm = Float(sin(breathPhase*0.5 - 0.45)), calmRight = Float(sin(breathPhase*0.5 - 0.65))
        let jiggle = panting * Float(sin(breathPhase - 1.2))
        let flick = cheering * Float(sin(cheerAge*2 * .pi/0.62))
        let flickRight = cheering * Float(sin(cheerAge*2 * .pi/0.62 + 0.9))
        // Something moving on screen: both ears perk up with interest.
        pose.leftEar = Self.earLimits(left: -profile.perkLeft - follow*0.06 + calm*0.018 - earRoll*0.5 + left.twitch*0.16
                                      - jiggle*0.025 - tap*0.05 - cheering*0.08 + flick*0.08
                                      + quirkPose.leftEar + min(0, cock.value)*0.45)
        pose.rightEar = Self.earLimits(right: profile.perkRight + follow*0.06 - calmRight*0.016 - earRoll*0.55 - right.twitch*0.145
                                       + jiggle*0.022 + tap*0.05 + cheering*0.07 - flickRight*0.07
                                       + quirkPose.rightEar + max(0, cock.value)*0.45)

        // Floppy ears: the lower half lags behind every move of the ear, the head and the hops.
        if let last = lastEars, dt > 0 {
            let rate = 1/Float(dt)
            let leftSpeed = (pose.leftEar-last.left)*rate, rightSpeed = (pose.rightEar-last.right)*rate
            let rollSpeed = (pose.headRoll-last.roll)*rate, liftSpeed = (pose.lift-last.lift)*rate
            let flap = panting*0.08*Float(sin(breathPhase - 1.6))
            let pull = SIMD2(leftSpeed*0.1 + rollSpeed*0.2 - liftSpeed*0.5 + flap,
                             -rightSpeed*0.1 - rollSpeed*0.2 - liftSpeed*0.5 + flap)
            bendPull += (pull.clamped(lowerBound: SIMD2(-0.45, -0.45), upperBound: SIMD2(0.45, 0.45)) - bendPull)
                * (1 - exp(-Float(dt)/0.08))
            leftBend.step(toward: bendPull.x, dt: dt, frequency: 1.8, damping: 0.45)
            rightBend.step(toward: bendPull.y, dt: dt, frequency: 1.8, damping: 0.45)
        }
        lastEars = (pose.leftEar, pose.rightEar, pose.headRoll, pose.lift)
        pose.leftEarBend = min(0.6, max(-0.6, leftBend.value))
        pose.rightEarBend = min(0.6, max(-0.6, rightBend.value))

        // The tongue drops out while panting and bounces a beat behind each breath.
        // Calm, it still rides the breath; every few seconds it licks the lips.
        let bounce = Float(sin(breathPhase - 0.6))
        let licking = lick.age > 0 && lick.age < lick.duration ? Float(lick.age/lick.duration) : 0
        let lickIn = licking > 0 ? Float(pow(sin(Double(licking) * .pi), 2)) * Float(lick.strength) : 0
        pose.tongueStretch = profile.tongueOut + panting*(0.13 + 0.05*bounce) + pose.breath*0.03*(1-panting)
            - lickIn*0.22 + quirkPose.tongueStretch
        pose.tonguePitch = panting*(0.05 + 0.035*bounce) + pose.breath*0.02*(1-panting)
            - lickIn*0.04 + quirkPose.tonguePitch
        // It hangs: when the head rolls it stays pointing down, and it lags when the head turns.
        let yawVelocity = lastYaw.map { dt > 0 ? (pose.headYaw-$0)/Float(dt) : 0 } ?? 0
        lastYaw = pose.headYaw
        let lickSweep = licking > 0 ? Float(sin(Double(licking) * 2 * .pi)) * lickIn * 0.22 : 0
        let swayTarget = -pose.headRoll*0.5 - yawVelocity*0.1
            + panting*0.05*Float(sin(breathPhase*0.5)) + lickSweep
        tongueSwing.step(toward: min(0.2, max(-0.2, swayTarget)), dt: dt, frequency: 1.8, damping: 0.45)
        pose.tongueSway = min(0.25, max(-0.25, tongueSwing.value))
        // Ofegando, a boca abre atrás da língua e o queixo acompanha cada fôlego; a ponta dá petelecos.
        pose.mouthOpen = max(quirkPose.mouth, panting*(0.26 + 0.06*bounce) + lickIn*0.12)
        pose.tongueCurl = min(1, lickIn + panting*0.18*max(0, bounce))
        pose.tongueRetract = quirkPose.retract
        pose.eyeWiden = min(1, profile.widen + follow*0.5)
        // Petting squints the eyes almost shut, the happy "^^" of a dog being scratched.
        pose.cheer = min(0.85, profile.cheer + panting*0.1 + cheering*0.06 + greeting*0.06 + happy*0.7
                         + quirkPose.cheer)
        lastTime = time
        return pose
    }
}


/// Um único relógio para o percurso em volta da cabeça e a mordida, repetido sem fim.
enum TobiSnackSequence {
    static let foods = ["🍎", "🍕", "🥦"]
    static let cycle = 4.2
    private static let speed = 1.7
    struct FoodFrame {
        let emoji: String
        let x: Double
        let y: Double
        let scale: Double
        let opacity: Double
        let rotation: Double
        let behind: Bool
    }
    static func ease(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t*t*(3-2*t)
    }
    private static func phase(_ time: Double) -> (index: Int, age: Double) {
        let time = time*speed
        let elapsed = max(0, time-0.35)
        let index = Int(elapsed/cycle)
        return (index, time-0.35-Double(index)*cycle)
    }
    private static func curve(_ t: Double, _ a: SIMD2<Double>, _ b: SIMD2<Double>,
                              _ c: SIMD2<Double>, _ d: SIMD2<Double>) -> SIMD2<Double> {
        let t = min(1, max(0, t)), u = 1-t
        return a*(u*u*u) + b*(3*u*u*t) + c*(3*u*t*t) + d*(t*t*t)
    }
    static func food(at time: Double) -> FoodFrame? {
        let (index, age) = phase(time)
        guard age >= 0, age < 3.5 else { return nil }
        let point: SIMD2<Double>
        if age < 0.9 {
            point = curve(age/0.9, [0.08,0.53], [0.15,0.48], [0.20,0.43], [0.32,0.43])
        } else if age < 1.9 {
            point = curve((age-0.9)/1.0, [0.32,0.43], [0.42,0.43], [0.63,0.43], [0.76,0.43])
        } else if age < 2.75 {
            point = curve((age-1.9)/0.85, [0.76,0.43], [0.91,0.43], [0.86,0.70], [0.68,0.68])
        } else {
            point = curve((age-2.75)/0.65, [0.68,0.68], [0.57,0.70], [0.51,0.65], [0.50,0.635])
        }
        let eaten = ease((age-3.16)/0.3)
        let distance = 1 - 0.15*ease(age/0.8) + 0.15*ease((age-1.9)/0.35)
        let shrink = 1 - 0.65*ease((age-2.9)/0.5)
        return FoodFrame(emoji: foods[index % foods.count], x: point.x, y: point.y,
                         scale: max(0.02, distance*shrink*(1-eaten)),
                         opacity: ease(age/0.14)*(1-ease((eaten-0.8)/0.2)),
                         rotation: 14*sin(age*1.2), behind: age < 1.9)
    }
    static func pose(_ base: TobiIdleBehavior.Pose, at time: Double) -> TobiIdleBehavior.Pose {
        var pose = base
        let (_, age) = phase(time)
        let engaged = Float(ease((age-2.2)/0.3) * (1-ease((age-3.65)/0.4)))
        pose.tongueRetract = max(pose.tongueRetract, engaged)
        pose.mouthOpen = Float(ease((age-2.55)/0.35)*(1-ease((age-3.32)/0.2)))*0.9
        let x = Float(food(at: time)?.x ?? 0.5)-0.5
        pose.headYaw = x*0.09
        pose.headRoll = x*0.025
        pose.gazeX = x*0.055
        pose.headPitch = 0
        pose.cheer = base.cheer*(1-engaged) + 0.04*engaged
        let chew = ease((age-3.5)/0.08)*(1-ease((age-3.85)/0.15))
        pose.headPitch += Float(chew*sin((age-3.5) * .pi * 10))*0.025
        let satisfied = Float(ease((age-3.5)/0.2)*(1-ease((age-3.95)/0.25)))
        pose.cheer = max(pose.cheer, satisfied*0.78)
        pose.headRoll += satisfied*0.045
        return pose
    }
}
