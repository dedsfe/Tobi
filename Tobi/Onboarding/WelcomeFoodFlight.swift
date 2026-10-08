import SwiftUI
import RealityKit

/// Só a boas-vindas conhece esta ponte; o rosto e suas poses continuam independentes.
@MainActor
final class WelcomeFoodScene {
    weak var view: ARView?
    var foodCenters: [Int: CGPoint] = [:]

    var isReady: Bool {
        guard let view, view.window != nil, view.bounds.height > 0 else { return false }
        return view.scene.findEntity(named: "Mouth") != nil
    }

    func landmarks(in target: UIView) -> (mouth: CGPoint, head: CGRect)? {
        guard let view, let mouth = view.scene.findEntity(named: "Mouth"),
              let head = view.scene.findEntity(named: "Head") else { return nil }
        // O centro da malha acompanha yaw, pitch, roll e a altura do rosto.
        let mouthCenter = mouth.visualBounds(relativeTo: mouth).center
        guard let projected = view.project(mouth.convert(position: mouthCenter, to: nil)) else { return nil }
        let bounds = head.visualBounds(relativeTo: head)
        var corners: [CGPoint] = []
        for x in [bounds.min.x, bounds.max.x] {
            for y in [bounds.min.y, bounds.max.y] {
                for z in [bounds.min.z, bounds.max.z] {
                    if let point = view.project(head.convert(position: [x, y, z], to: nil)) {
                        corners.append(view.convert(point, to: target))
                    }
                }
            }
        }
        guard let first = corners.first else { return nil }
        let rect = corners.dropFirst().reduce(CGRect(origin: first, size: .zero)) { rect, point in
            CGRect(x: min(rect.minX, point.x), y: min(rect.minY, point.y),
                   width: max(rect.maxX, point.x) - min(rect.minX, point.x),
                   height: max(rect.maxY, point.y) - min(rect.minY, point.y))
        }
        return (view.convert(projected, to: target), rect)
    }
}

/// Encontra apenas o ARView vizinho ao palco, sem alterar o renderer da outra sessão.
struct WelcomeFoodStageCapture: UIViewRepresentable {
    let scene: WelcomeFoodScene

    func makeUIView(context: Context) -> Capture {
        let view = Capture()
        view.scene = scene
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: Capture, context: Context) { uiView.capture() }

    final class Capture: UIView {
        var scene: WelcomeFoodScene?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            capture()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            capture()
        }

        func capture() {
            guard window != nil else { return }
            func find(in root: UIView) -> ARView? {
                if let view = root as? ARView { return view }
                for child in root.subviews {
                    if let found = find(in: child) { return found }
                }
                return nil
            }
            var ancestor = superview
            // O background e o palco podem ter wrappers separados do SwiftUI.
            for _ in 0..<6 {
                guard let root = ancestor else { break }
                if let view = find(in: root) { scene?.view = view; return }
                ancestor = root.superview
            }
        }
    }
}

/// Um único emoji, a 30 fps, atrás ou à frente do ARView transparente.
struct WelcomeFoodFlight: UIViewRepresentable {
    let scene: WelcomeFoodScene
    let emoji: String
    let size: CGFloat
    let tilt: Double
    let origin: CGPoint
    let started: TimeInterval
    let duration: Double
    let enabled: Bool
    let onBite: () -> Void

    func makeUIView(context: Context) -> FlightView {
        let view = FlightView()
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ view: FlightView, context: Context) { view.configure(self) }

    static func dismantleUIView(_ view: FlightView, coordinator: ()) { view.stop() }

    final class FlightView: UIView {
        private var flight: WelcomeFoodFlight?
        private var link: CADisplayLink?
        private let emoji = UILabel()
        private var completed: TimeInterval?
        private var wasBehind: Bool?
        private weak var frontContainer: UIView?

        func configure(_ flight: WelcomeFoodFlight) {
            self.flight = flight
            guard flight.enabled, completed != flight.started else { stop(); return }
            emoji.text = flight.emoji
            emoji.font = .systemFont(ofSize: flight.size)
            emoji.textAlignment = .center
            emoji.isUserInteractionEnabled = false
            emoji.accessibilityElementsHidden = true
            emoji.bounds = CGRect(x: 0, y: 0, width: flight.size * 1.5, height: flight.size * 1.5)
            if link == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
                link.add(to: .main, forMode: .common)
                self.link = link
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { stop() }
        }

        func stop() {
            link?.invalidate()
            link = nil
            emoji.removeFromSuperview()
            wasBehind = nil
            frontContainer = nil
        }

        /// O ancestral comum contém mesa e palco, então a subida não corta nas bordas.
        private func frontHost(for arView: ARView) -> UIView {
            if let frontContainer { return frontContainer }
            var ancestor = arView.superview
            while let root = ancestor {
                if isDescendant(of: root) {
                    frontContainer = root
                    return root
                }
                ancestor = root.superview
            }
            return self
        }

        @objc private func tick() {
            guard let flight, flight.enabled, window != nil,
                  let arView = flight.scene.view, arView.window === window,
                  let landmarks = flight.scene.landmarks(in: self) else { stop(); return }
            let t = min(1, max(0, (Date.now.timeIntervalSinceReferenceDate - flight.started) / flight.duration))
            if t >= 1 {
                completed = flight.started
                stop()
                flight.onBite()
                return
            }
            let behind = t >= 0.25 && t < 0.75
            let point = WelcomeFoodRoute.point(from: flight.origin, to: landmarks.mouth, head: landmarks.head,
                                              margin: flight.size * 0.9, at: t)
            // A troca de camada acontece fora do contorno, nos dois lados da cabeça.
            if behind, let parent = arView.superview {
                if emoji.superview !== parent || wasBehind != behind {
                    parent.insertSubview(emoji, belowSubview: arView)
                    wasBehind = behind
                }
                emoji.center = convert(point, to: parent)
            } else {
                let parent = frontHost(for: arView)
                if emoji.superview !== parent || wasBehind != behind {
                    parent.addSubview(emoji)
                    wasBehind = behind
                }
                emoji.center = convert(point, to: parent)
            }
            let far = 1 - 0.3 * sin(.pi * min(1, t / 0.85))
            let bite = t > 0.85 ? max(0.01, (1 - t) / 0.15) : 1
            emoji.transform = CGAffineTransform(rotationAngle: (flight.tilt + t * 200) * .pi / 180)
                .scaledBy(x: far * bite, y: far * bite)
        }
    }
}
