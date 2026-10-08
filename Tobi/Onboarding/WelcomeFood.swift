import SwiftUI

/// O vazio da boas-vindas vira mesa farta: comidas no mesmo estilo do rosto do Tobi, soltas no ar,
/// balançando devagar. Algumas mostram quanto valem, como o Tobi mostraria.
/// Tocar numa comida faz ela pular e estourar, e o Tobi lá em cima fica feliz.
struct WelcomeFood: View {
    let scene: WelcomeFoodScene
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tobiReactions) private var tobi
    @State private var shown = false
    /// Quantas vezes cada comida foi tocada; cada toque toca a reação de novo.
    @State private var taps = Array(repeating: 0, count: WelcomeFood.items.count)
    /// A comida que está indo pra boca do Tobi agora, e quando saiu.
    @State private var trip: (index: Int, start: TimeInterval, origin: CGPoint)?
    @State private var chomps = 0
    @State private var lastFood = -1

    /// Voo até a boca, sumida, e a bolha estourando onde ela estava.
    private static let flight = 1.5
    private static let away = 0.35
    private static let pop = 0.45

    private struct Item {
        let emoji: String
        /// Posição no palco, de 0 a 1.
        let spot: UnitPoint
        let size: CGFloat
        let tilt: Double
        /// Calorias de uma porção comum (TACO / rótulos), só em algumas.
        var kcal: String?
    }

    private static let items: [Item] = [
        Item(emoji: "🍕", spot: UnitPoint(x: 0.16, y: 0.20), size: 58, tilt: -12, kcal: "~280 cal"),
        Item(emoji: "🥑", spot: UnitPoint(x: 0.52, y: 0.10), size: 40, tilt: 10),
        Item(emoji: "🍓", spot: UnitPoint(x: 0.84, y: 0.22), size: 44, tilt: 14),
        Item(emoji: "🥐", spot: UnitPoint(x: 0.36, y: 0.48), size: 46, tilt: -6),
        Item(emoji: "🍔", spot: UnitPoint(x: 0.76, y: 0.56), size: 62, tilt: 8, kcal: "~500 cal"),
        Item(emoji: "🍣", spot: UnitPoint(x: 0.10, y: 0.70), size: 40, tilt: 6),
        Item(emoji: "🍌", spot: UnitPoint(x: 0.44, y: 0.86), size: 44, tilt: -18, kcal: "~70 cal"),
        Item(emoji: "☕️", spot: UnitPoint(x: 0.90, y: 0.88), size: 36, tilt: -4),
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !shown || scenePhase != .active)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Self.items.indices, id: \.self) { index in
                        let item = Self.items[index]
                        let spot = CGPoint(x: proxy.size.width * item.spot.x, y: proxy.size.height * item.spot.y)
                        let elapsed = trip.flatMap { $0.index == index ? time - $0.start : nil }
                        if let elapsed, elapsed < Self.flight + Self.away {
                            EmptyView()
                        } else if let elapsed, elapsed < Self.flight + Self.away + Self.pop {
                            // Volta estourando uma bolha no lugar onde estava.
                            let progress = (elapsed - Self.flight - Self.away) / Self.pop
                            ZStack {
                                Bubble(progress: progress, size: item.size)
                                food(item, index: index, time: time)
                                    .scaleEffect(Self.backOut(progress))
                            }
                            .position(spot)
                        } else {
                            food(item, index: index, time: time)
                                .position(spot)
                        }
                    }
                }
            }
            .overlay {
                if let trip {
                    let item = Self.items[trip.index]
                    let frame = proxy.frame(in: .global)
                    WelcomeFoodFlight(scene: scene, emoji: item.emoji, size: item.size,
                                      tilt: item.tilt + sin(trip.start * 0.8 + Double(trip.index) * 1.3) * 4,
                                      origin: CGPoint(x: trip.origin.x - frame.minX,
                                                      y: trip.origin.y - frame.minY),
                                      started: trip.start, duration: Self.flight,
                                      enabled: !reduceMotion && scenePhase == .active) {
                        guard !reduceMotion, scenePhase == .active else { return }
                        chomps += 1
                        tobi.acknowledge()
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .onAppear { shown = true }
        .onDisappear { shown = false; trip = nil }
        .task(id: reduceMotion || scenePhase != .active) { await feed() }
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .sensoryFeedback(.impact(weight: .light), trigger: chomps)
        .accessibilityHidden(true)
    }

    /// Para sempre: uma comida por vez, sorteada (nunca a mesma de antes), vai pra boca do Tobi.
    private func feed() async {
        trip = nil
        guard !reduceMotion, scenePhase == .active else { return }
        do {
            try await Task.sleep(for: .seconds(1.6))
            while !Task.isCancelled {
                // Espera o rosto carregar, sem inventar uma boca pro fallback.
                while !scene.isReady || scene.foodCenters.count < Self.items.count {
                    try await Task.sleep(for: .milliseconds(100))
                }
                let choices = Self.items.indices.filter { $0 != lastFood }
                guard let next = choices.randomElement() else { return }
                guard let origin = scene.foodCenters[next] else { continue }
                lastFood = next
                trip = (next, Date.now.timeIntervalSinceReferenceDate, origin)
                try await Task.sleep(for: .seconds(Self.flight + Self.away + Self.pop + 1.1))
            }
        } catch {
            // Ao sair ou pausar, a comida volta pra mesa.
        }
    }

    /// Cresce passando um pouquinho do tamanho e assenta, como quem acabou de brotar.
    private static func backOut(_ t: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }

    /// Cada comida flutua no seu ritmo; as que têm calorias carregam uma pílula de vidro junto.
    private func food(_ item: Item, index: Int, time: Double) -> some View {
        let phase = Double(index) * 1.3
        let bob = reduceMotion ? 0 : sin(time * 1.1 + phase) * 6
        let sway = reduceMotion ? 0 : sin(time * 0.8 + phase) * 4
        return VStack(spacing: 2) {
            Text(item.emoji)
                .font(.system(size: item.size))
                .rotationEffect(.degrees(item.tilt + sway))
                .keyframeAnimator(initialValue: Pop(), trigger: taps[index]) { content, pop in
                    content
                        .scaleEffect(pop.scale)
                        .rotationEffect(.degrees(pop.wiggle))
                        .offset(y: pop.lift)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(0.8, duration: 0.08)
                        CubicKeyframe(1.35, duration: 0.16)
                        SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                    }
                    KeyframeTrack(\.lift) {
                        CubicKeyframe(4, duration: 0.08)
                        CubicKeyframe(-26, duration: 0.18)
                        SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                    }
                    KeyframeTrack(\.wiggle) {
                        CubicKeyframe(-14, duration: 0.12)
                        CubicKeyframe(12, duration: 0.12)
                        CubicKeyframe(-6, duration: 0.12)
                        SpringKeyframe(0, duration: 0.3)
                    }
                }
                .overlay {
                    if taps[index] > 0 && !reduceMotion {
                        GeometryReader { box in
                            ConfettiBurst(origin: CGPoint(x: box.size.width / 2, y: box.size.height / 2))
                        }
                        .id(taps[index])
                    }
                }
                .onGeometryChange(for: CGPoint.self) { proxy in
                    let frame = proxy.frame(in: .global)
                    return CGPoint(x: frame.midX, y: frame.midY)
                } action: { center in
                    scene.foodCenters[index] = center
                }
                .contentShape(.rect)
                .onTapGesture {
                    guard !reduceMotion else { tobi.acknowledge(); return }
                    taps[index] += 1
                    tobi.acknowledge()
                }
            if let kcal = item.kcal {
                Text(kcal)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    .fixedSize()
            }
        }
        .offset(y: bob)
    }

    private struct Pop {
        var scale: CGFloat = 1
        var lift: CGFloat = 0
        var wiggle: Double = 0
    }
}

/// Bolha de sabão estourando: o contorno cresce e some, e respingam gotinhas.
private struct Bubble: View {
    let progress: Double
    let size: CGFloat

    var body: some View {
        let reach = size * (0.7 + 0.6 * progress)
        ZStack {
            Circle()
                .stroke(Color.indigo.opacity(0.35 * (1 - progress)), lineWidth: 2)
                .frame(width: reach, height: reach)
            ForEach(0..<6, id: \.self) { drop in
                let angle = Double(drop) / 6 * 2 * .pi + 0.4
                Circle()
                    .fill(Color.indigo.opacity(0.4 * (1 - progress)))
                    .frame(width: 4, height: 4)
                    .offset(x: cos(angle) * reach * 0.62, y: sin(angle) * reach * 0.62)
            }
        }
        .allowsHitTesting(false)
    }
}
