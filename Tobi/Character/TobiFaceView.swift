import SwiftUI
import RealityKit
import UIKit

/// O modelo esculpido é composto de malhas nomeadas, não de um billboard.
struct TobiFaceAsset: Decodable, Sendable {
    struct Part: Decodable, Sendable {
        let name: String
        let color: [Float]
        let roughness: Float
        let vertices: [[Float]]
        let normals: [[Float]]
        let triangles: [UInt32]
        let position: [Float]?
        /// Canais de pose (boca abrindo, língua enrolando, orelha dobrando e levantando).
        let morphs: [Morph]?
    }
    /// Poses com a mesma topologia, distribuídas por igual em `range`. O repouso é o valor 0.
    struct Morph: Decodable, Sendable {
        let name: String
        let range: [Float]
        let poses: [[[Float]]]
        let normals: [[[Float]]]
    }
    let parts: [Part]
}

/// Malha deformável: cada canal mistura as duas poses vizinhas e soma a diferença sobre o repouso,
/// direto no buffer da GPU. Não gera malha nova por quadro, então pode mexer o tempo todo.
@MainActor
final class TobiPosableMesh {
    private struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }
    private struct Channel {
        let positions: [[SIMD3<Float>]]
        let normals: [[SIMD3<Float>]]
        let range: ClosedRange<Float>
    }

    let resource: MeshResource
    private let mesh: LowLevelMesh
    private let restPositions: [SIMD3<Float>]
    private let restNormals: [SIMD3<Float>]
    private let channels: [String: Channel]
    private var weights: [String: Float] = [:]
    private var written: [String: Float] = [:]

    init?(_ part: TobiFaceAsset.Part) throws {
        let count = part.vertices.count
        guard let morphs = part.morphs, !morphs.isEmpty else { return nil }
        var channels: [String: Channel] = [:]
        for morph in morphs {
            guard morph.poses.count >= 2, morph.normals.count == morph.poses.count, morph.range.count == 2,
                  morph.range[0] < morph.range[1],
                  morph.poses.allSatisfy({ $0.count == count }), morph.normals.allSatisfy({ $0.count == count })
            else { return nil }
            channels[morph.name] = Channel(positions: morph.poses.map { $0.map { SIMD3($0[0], $0[1], $0[2]) } },
                                           normals: morph.normals.map { $0.map { SIMD3($0[0], $0[1], $0[2]) } },
                                           range: morph.range[0]...morph.range[1])
        }
        self.channels = channels
        restPositions = part.vertices.map { SIMD3($0[0], $0[1], $0[2]) }
        restNormals = part.normals.map { SIMD3($0[0], $0[1], $0[2]) }

        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexCapacity = count
        descriptor.indexCapacity = part.triangles.count
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
            .init(semantic: .normal, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.normal)!),
        ]
        descriptor.vertexLayouts = [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)]
        descriptor.indexType = .uint32
        mesh = try LowLevelMesh(descriptor: descriptor)
        mesh.withUnsafeMutableIndices { raw in
            let indices = raw.bindMemory(to: UInt32.self)
            for (index, value) in part.triangles.enumerated() { indices[index] = value }
        }
        // A caixa cobre todas as poses, para nunca sumir no recorte da câmera.
        var box = BoundingBox()
        for point in restPositions { box.formUnion(point) }
        for channel in channels.values { for pose in channel.positions { for point in pose { box.formUnion(point) } } }
        // Canais somados podem passar um pouco de cada pose sozinha.
        box = BoundingBox(min: box.min - 0.05, max: box.max + 0.05)
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: part.triangles.count, topology: .triangle, bounds: box)])
        resource = try MeshResource(from: mesh)
        commit(force: true)
    }

    /// Guarda o peso de um canal; `commit()` escreve tudo de uma vez.
    func set(_ name: String, _ value: Float) {
        guard let channel = channels[name] else { return }
        weights[name] = min(channel.range.upperBound, max(channel.range.lowerBound, value.isFinite ? value : 0))
    }

    func commit(force: Bool = false) {
        guard force || weights.contains(where: { abs($0.value - (written[$0.key] ?? 0)) > 0.0005 }) else { return }
        written = weights
        var positions = restPositions
        var normals = restNormals
        for (name, value) in weights where value != 0 {
            guard let channel = channels[name] else { continue }
            let span = channel.range.upperBound - channel.range.lowerBound
            let position = (value - channel.range.lowerBound)/span * Float(channel.positions.count-1)
            let index = min(channel.positions.count-2, Int(position))
            let mix = position - Float(index)
            let a = channel.positions[index], b = channel.positions[index+1]
            let na = channel.normals[index], nb = channel.normals[index+1]
            for i in positions.indices {
                positions[i] += a[i] + (b[i]-a[i])*mix - restPositions[i]
                normals[i] += na[i] + (nb[i]-na[i])*mix - restNormals[i]
            }
        }
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let vertices = raw.bindMemory(to: Vertex.self)
            for i in positions.indices {
                vertices[i] = Vertex(position: positions[i], normal: simd_normalize(normals[i]))
            }
        }
    }
}

/// O modelo lido uma vez, fora da main thread, e compartilhado por todos os palcos.
/// As poses da piscada nascem na primeira vez que são usadas, então abrir o palco não trava a tela.
@MainActor
final class TobiFaceLibrary {
    static let shared = TobiFaceLibrary()
    static let blinkSteps = 48

    private(set) var asset: TobiFaceAsset?
    private var loading: Task<TobiFaceAsset?, Never>?
    private var blinkPoses: [String: [MeshResource?]] = [:]

    func load() async -> TobiFaceAsset? {
        if let asset { return asset }
        let task = loading ?? Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: "tobi-face", withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(TobiFaceAsset.self, from: data)
        }
        loading = task
        asset = await task.value
        return asset
    }

    func mesh(_ part: TobiFaceAsset.Part) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: part.name)
        descriptor.positions = .init(part.vertices.map { SIMD3($0[0], $0[1], $0[2]) })
        descriptor.normals = .init(part.normals.map { SIMD3($0[0], $0[1], $0[2]) })
        descriptor.primitives = .triangles(part.triangles)
        return try MeshResource.generate(from: [descriptor])
    }

    /// Same topology from open eye to closed crease: no visibility swap.
    func blinkPose(_ part: TobiFaceAsset.Part, step: Int) throws -> MeshResource {
        var poses = blinkPoses[part.name] ?? Array(repeating: nil, count: Self.blinkSteps + 1)
        if let pose = poses[step] { return pose }
        let pose = try Self.blinkMesh(part, closed: Float(step)/Float(Self.blinkSteps))
        poses[step] = pose
        blinkPoses[part.name] = poses
        return pose
    }

    /// Deform the eye into a thin curved crease without replacing its geometry.
    private static func blinkMesh(_ part: TobiFaceAsset.Part, closed: Float) throws -> MeshResource {
        let height = 1 - closed * (1 - 0.0025/0.15)
        let depth = 1 - closed * 0.82
        let width = 1 - closed * 0.10
        var descriptor = MeshDescriptor(name: part.name + "Blink")
        descriptor.positions = .init(part.vertices.map { vertex in
            let x = vertex[0] * width
            let curve = closed * (0.008 - 0.016 * pow(x/0.066, 2))
            return SIMD3(x, vertex[1]*height + curve, vertex[2]*depth + closed*0.035)
        })
        descriptor.normals = .init(zip(part.vertices, part.normals).map { vertex, normal in
            let slope = -closed * 0.032 * vertex[0]*width / (0.066*0.066)
            let ny = normal[1]/height
            return simd_normalize(SIMD3(normal[0]/width - slope*ny, ny, normal[2]/depth))
        })
        descriptor.primitives = .triangles(part.triangles)
        return try MeshResource.generate(from: [descriptor])
    }
}

/// O que o palco pede ao Tobi: o estado da tela e as reações, como contadores.
/// Só mudanças contam, então redesenhar a tela não reinicia nenhum relógio.
struct TobiPerformance: Equatable {
    var mood = TobiIdleBehavior.Mood.joyful
    /// Muda a cada troca de tela, ou quando a mesma tela pede para se apresentar de novo.
    var scene = 0
    /// Indo para frente toca o gesto de entrada do estado; voltando, só recupera o estado.
    var entering = true
    var acknowledgements = 0
    /// Toques no próprio Tobi.
    var pets = 0
    /// O laboratório pede manias uma de cada vez e desliga as que vêm sozinhas.
    var quirkRequest: TobiIdleBehavior.Quirk?
    var quirks = 0
    var licks = 0
    var spontaneous = true
}

/// Vê todo toque na janela sem participar: não cancela, não atrasa e não impede nenhum outro gesto.
final class TobiFingerWatcher: UIGestureRecognizer, UIGestureRecognizerDelegate {
    /// Onde está o dedo, nas coordenadas da janela. `nil` sem dedo na tela.
    private(set) var point: CGPoint?

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { point = touches.first?.location(in: nil) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { point = touches.first?.location(in: nil) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift() }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    private func lift() {
        point = nil
        state = .failed
    }

    /// Sai da janela esquecendo o último dedo, para não voltar olhando pra um toque antigo.
    func detach() {
        view?.removeGestureRecognizer(self)
        point = nil
    }
}

@MainActor
struct TobiFaceView: UIViewRepresentable {
    var isPlaying: Bool
    var blinkRequest: Int
    var lookRequest: Int
    var isActive: Bool
    var reduceMotion: Bool
    /// O laboratório usa o padrão: alegre, sem reações.
    var performance = TobiPerformance()
    /// No onboarding ele acompanha o dedo pela tela inteira.
    var followsFinger = false
    /// Experimento disponível apenas no laboratório dos Ajustes.
    var showsBody = false
    /// Relógio compartilhado com os emojis no experimento de comer.
    var eatingTime: Double? = nil
    var onFailure: () -> Void = { }
    /// Chamado quando o modelo termina de carregar depois de o palco já estar na tela.
    var onReady: () -> Void = { }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.environment.background = .color(.clear)
        view.isUserInteractionEnabled = false
        view.accessibilityLabel = "Tobi"
        context.coordinator.onFailure = onFailure
        context.coordinator.onReady = onReady
        context.coordinator.showsBody = showsBody
        context.coordinator.install(in: view)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.onReady = onReady
        context.coordinator.onFailure = onFailure
        context.coordinator.eatingTime = eatingTime
        context.coordinator.followsFinger = followsFinger
        context.coordinator.configure(isPlaying: isPlaying, blink: blinkRequest,
                                      look: lookRequest, active: isActive, reduced: reduceMotion,
                                      performance: performance)
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let anchor = AnchorEntity(world: .zero)
        private let face = Entity()
        private let body = Entity()
        private let tail = Entity()
        var showsBody = false
        var eatingTime: Double?
        private var sockets: [Entity] = []
        private var eyeMeshes: [ModelEntity] = []
        private var eyeParts: [TobiFaceAsset.Part] = []
        private var ears: [ModelEntity] = []
        private var tongue: ModelEntity?
        private var tongueRest = SIMD3<Float>(0, 0, 0)
        private var posable: [String: TobiPosableMesh] = [:]
        private struct Droplet {
            let entity: ModelEntity
            let origin: SIMD3<Float>
            let velocity: SIMD3<Float>
            let size: Float
            let born: CFTimeInterval
            let life: Double
        }
        private var droplets: [Droplet] = []
        private var lastSneeze = 0
        private var lastFinger: (point: CGPoint, time: CFTimeInterval)?
        private var link: CADisplayLink?
        private var start = CACurrentMediaTime()
        private var playing = false
        private var active = true
        private var reduced = false
        private var lastBlinkRequest = 0
        private var lastLookRequest = 0
        private var blinkStart: CFTimeInterval?
        private var lookStart: CFTimeInterval?
        private var idle = TobiIdleBehavior()
        private var performance: TobiPerformance?
        private var socketPositions: [SIMD3<Float>] = []
        private var lastLidPose = -1
        private weak var view: ARView?
        private let finger = TobiFingerWatcher()
        var followsFinger = false
        private(set) var generationFailed = false
        var onFailure: () -> Void = { }
        var onReady: () -> Void = { }

        func install(in view: ARView) {
            self.view = view
            face.name = "Tobi"
            anchor.addChild(face)
            view.scene.addAnchor(anchor)

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 30
            let center: Float = showsBody ? -0.3 : 0.02
            camera.look(at: [0, center, 0], from: [0, center, showsBody ? 6.2 : 7.8], relativeTo: nil)
            anchor.addChild(camera)

            for (position, intensity) in [(SIMD3<Float>(-2, 3, 4), Float(1200)),
                                          (SIMD3<Float>(2, 1, 3), Float(400)),
                                          (SIMD3<Float>(0, -2, 3), Float(150))] {
                let light = DirectionalLight()
                light.light.intensity = intensity
                light.look(at: .zero, from: position, relativeTo: nil)
                anchor.addChild(light)
            }

            if let asset = TobiFaceLibrary.shared.asset {
                build(asset, in: view)
                if !generationFailed { Task { @MainActor [weak self] in self?.onReady() } }
            } else {
                Task { [weak self, weak view] in
                    let asset = await TobiFaceLibrary.shared.load()
                    guard let self, let view else { return }
                    self.build(asset, in: view)
                    if !self.generationFailed { self.onReady() }
                }
            }
        }

        private func build(_ asset: TobiFaceAsset?, in view: ARView) {
            do {
                guard let asset else { throw CocoaError(.fileReadCorruptFile) }
                let library = TobiFaceLibrary.shared
                for part in asset.parts {
                    let material = SimpleMaterial(color: UIColor(red: CGFloat(part.color[0]),
                                                                 green: CGFloat(part.color[1]),
                                                                 blue: CGFloat(part.color[2]), alpha: 1),
                                                  roughness: .init(floatLiteral: part.roughness), isMetallic: false)
                    let deformable = try TobiPosableMesh(part)
                    let entity = ModelEntity(mesh: try deformable?.resource ?? library.mesh(part), materials: [material])
                    entity.name = part.name
                    if let deformable { posable[part.name] = deformable }
                    if let position = part.position, part.name == "EyeLeft" || part.name == "EyeRight" {
                        let socket = Entity()
                        socket.name = part.name + "Socket"
                        socket.position = SIMD3(position[0], position[1], position[2])
                        socket.addChild(entity)
                        face.addChild(socket)
                        sockets.append(socket)
                        socketPositions.append(socket.position)
                        eyeMeshes.append(entity)
                        eyeParts.append(part)
                    } else {
                        if let position = part.position {
                            entity.position = SIMD3(position[0], position[1], position[2])
                        }
                        face.addChild(entity)
                        if part.name.hasPrefix("Ear") { ears.append(entity) }
                        if part.name == "Tongue" {
                            tongue = entity
                            tongueRest = entity.position
                        }
                    }
                }
                if showsBody { try buildBody(asset) }
                lastLidPose = -1
                if link == nil { stop() }
            } catch {
                generationFailed = true
                stop()
                // A camada SwiftUI mantém o emoji visível quando o asset falha.
                view.accessibilityLabel = "Não foi possível carregar o Tobi 3D"
                Task { @MainActor in self.onFailure() }
            }
        }

        /// Cachorrinho sentado: peito curto, quadris arredondados e patinhas apoiadas.
        /// O rosto continua com seu próprio pivô, independente do tronco.
        private func buildBody(_ asset: TobiFaceAsset) throws {
            let white = asset.parts.first(where: { $0.name == "Head" })?.color ?? [0.98, 0.97, 0.95]
            let brown = asset.parts.first(where: { $0.name == "EarLeft" })?.color ?? [0.65, 0.32, 0.1]
            func material(_ color: [Float]) -> SimpleMaterial {
                SimpleMaterial(color: UIColor(red: CGFloat(color[0]), green: CGFloat(color[1]),
                                              blue: CGFloat(color[2]), alpha: 1), roughness: 0.45, isMetallic: false)
            }
            let fur = material(white), tan = material(brown)
            let sphere = MeshResource.generateSphere(radius: 1)
            func rounded(_ name: String, _ position: SIMD3<Float>, _ radii: SIMD3<Float>,
                         _ finish: SimpleMaterial, in parent: Entity) {
                let part = ModelEntity(mesh: sphere, materials: [finish])
                part.name = name
                part.position = position
                part.scale = radii
                parent.addChild(part)
            }
            body.name = "TinyBody"
            anchor.addChild(body)
            rounded("Chest", [0,-0.95,-0.02], [0.3,0.38,0.25], fur, in: body)
            rounded("Neck", [0,-0.65,0], [0.19,0.19,0.17], fur, in: body)
            for side: Float in [-1,1] {
                rounded(side < 0 ? "HaunchLeft" : "HaunchRight",
                        [side*0.29,-1.18,-0.04], [0.19,0.2,0.25], fur, in: body)
                rounded(side < 0 ? "HindPawLeft" : "HindPawRight",
                        [side*0.31,-1.32,0.12], [0.17,0.09,0.2], fur, in: body)
                rounded(side < 0 ? "ForelegLeft" : "ForelegRight",
                        [side*0.15,-1.1,0.23], [0.095,0.23,0.1], fur, in: body)
                rounded(side < 0 ? "FrontPawLeft" : "FrontPawRight",
                        [side*0.15,-1.34,0.3], [0.13,0.095,0.18], fur, in: body)
            }
            tail.name = "Tail"
            tail.position = [0.26,-1.08,-0.19]
            body.addChild(tail)
            // Um rabinho curvo e afilado, com seção circular e normais suaves.
            var vertices: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []
            let rings = 24, sides = 12
            for ring in 0...rings {
                let t = Float(ring)/Float(rings), angle = t * .pi * 0.8
                let center = SIMD3<Float>(0.3*sin(angle), 0.3*(1-cos(angle)), -0.06*t)
                let tangent = simd_normalize(SIMD3<Float>(0.3*cos(angle), 0.3*sin(angle), -0.06/(.pi*0.8)))
                let across = simd_normalize(simd_cross(tangent, SIMD3<Float>(0,0,1)))
                let normal = simd_normalize(simd_cross(across, tangent))
                let radius = 0.065 * sqrt(max(0.001, 1-t*t))
                for side in 0..<sides {
                    let phi = Float(side)/Float(sides)*2 * .pi
                    let direction = across*cos(phi) + normal*sin(phi)
                    vertices.append(center + radius*direction)
                    normals.append(direction)
                    if ring < rings {
                        let a = UInt32(ring*sides+side), b = UInt32(ring*sides+(side+1)%sides)
                        let c = a+UInt32(sides), d = b+UInt32(sides)
                        indices += [a,c,b,b,c,d]
                    }
                }
            }
            var descriptor = MeshDescriptor(name: "CurledTail")
            descriptor.positions = .init(vertices)
            descriptor.normals = .init(normals)
            descriptor.primitives = .triangles(indices)
            let mesh = try MeshResource.generate(from: [descriptor])
            tail.addChild(ModelEntity(mesh: mesh, materials: [tan]))
        }

        private func applySoftParts(_ pose: TobiIdleBehavior.Pose) {
            for ear in ears {
                let angle = ear.name == "EarLeft" ? pose.leftEar : pose.rightEar
                ear.orientation = simd_quatf(angle: angle, axis: [0,0,1])
                    * simd_quatf(angle: angle*0.35, axis: [1,0,0])
            }
            for (name, bend) in [("EarLeft", pose.leftEarBend), ("EarRight", pose.rightEarBend)] {
                posable[name]?.set("bend", bend)
                posable[name]?.commit()
            }
            // Recolher a língua a puxa pra dentro da boca; abrir a boca desce a língua junto com o queixo.
            let retract = pose.tongueRetract
            tongue?.position = tongueRest + SIMD3(0, 0.01*retract - 0.04*pose.mouthOpen*(1-retract), -0.06*retract)
            tongue?.orientation = simd_quatf(angle: pose.tongueSway, axis: [0,0,1])
                * simd_quatf(angle: pose.tonguePitch, axis: [1,0,0])
            tongue?.scale = [1 - 0.3*retract, max(0.02, pose.tongueStretch*(1 - 0.95*retract)), 1 - 0.3*retract]
            posable["Tongue"]?.set("curl", pose.tongueCurl)
            posable["Tongue"]?.commit()
            for name in ["Mouth", "MouthTongue"] {
                posable[name]?.set("open", pose.mouthOpen)
                posable[name]?.commit()
            }
        }

        func configure(isPlaying: Bool, blink: Int, look: Int, active: Bool, reduced: Bool,
                       performance: TobiPerformance) {
            let resumed = active && (!self.active || (self.reduced && !reduced))
            self.active = active
            self.reduced = reduced
            if resumed || playing != isPlaying {
                playing = isPlaying
                restartClocks()
            }
            perform(performance)
            if blink != lastBlinkRequest {
                lastBlinkRequest = blink
                if !reduced { blinkStart = CACurrentMediaTime() }
            }
            if look != lastLookRequest {
                lastLookRequest = look
                if !reduced { lookStart = CACurrentMediaTime() }
            }
            if active && !reduced && (playing || blinkStart != nil || lookStart != nil) && !generationFailed {
                if link == nil {
                    let displayLink = CADisplayLink(target: self, selector: #selector(step))
                    displayLink.add(to: .main, forMode: .common)
                    link = displayLink
                }
            } else {
                stop()
            }
        }

        /// Relógios novos depois de uma pausa, mantendo o estado sem repetir o gesto de entrada.
        private func restartClocks() {
            let mood = idle.mood
            start = CACurrentMediaTime()
            idle = TobiIdleBehavior()
            idle.spontaneous = performance?.spontaneous ?? true
            idle.setMood(mood, at: 0, entering: false)
        }

        private func perform(_ next: TobiPerformance) {
            defer { performance = next }
            let now = CACurrentMediaTime() - start
            let moving = active && !reduced && playing
            idle.spontaneous = next.spontaneous
            guard let performance else {
                return idle.setMood(next.mood, at: now, entering: next.entering && moving)
            }
            if next.scene != performance.scene || next.mood != performance.mood {
                idle.setMood(next.mood, at: now, entering: next.entering && moving)
            }
            if next.acknowledgements != performance.acknowledgements && moving {
                idle.acknowledge(at: now)
            }
            if next.pets != performance.pets && moving {
                for _ in 0..<min(3, max(0, next.pets-performance.pets)) { idle.pet(at: now) }
            }
            if next.quirks != performance.quirks, let quirk = next.quirkRequest, moving {
                idle.perform(quirk, at: now)
            }
            if next.licks != performance.licks && moving {
                idle.lickNow(at: now)
            }
        }

        /// Parado (pausa, segundo plano ou Movimento Reduzido), o rosto fica na expressão do estado.
        func stop() {
            finger.detach()
            for drop in droplets { drop.entity.removeFromParent() }
            droplets.removeAll()
            link?.invalidate()
            link = nil
            blinkStart = nil
            lookStart = nil
            apply(TobiIdleBehavior.still(idle.mood))
        }

        @objc private func step(_ displayLink: CADisplayLink) {
            let now = displayLink.timestamp
            let elapsed = now-start
            if followsFinger {
                if finger.view == nil { view?.window?.addGestureRecognizer(finger) }
                idle.follow(fingerDirection(), swipe: fingerSwipe(at: now), at: elapsed)
            } else if finger.view != nil {
                finger.detach()
                lastFinger = nil
                idle.follow(nil, at: elapsed)
            }
            var pose = playing ? idle.sample(at: elapsed) : TobiIdleBehavior.still(idle.mood)
            if let blinkStart {
                let age = now-blinkStart
                pose.blink = TobiIdleBehavior.blinkClosure(age: age)
                if age >= Motion.tobiBlinkClose + Motion.tobiBlinkHold + Motion.tobiBlinkOpen {
                    self.blinkStart = nil
                }
            }
            if let lookStart {
                let t = now-lookStart
                let attention = Float(TobiIdleBehavior.ease(t/0.35) * TobiIdleBehavior.ease((Motion.tobiLookDuration-t)/0.65))
                pose.gazeX = -0.025*attention
                pose.gazeY = 0.005*attention
                pose.headYaw = -0.075*attention
                pose.headRoll += -0.045*attention
                if t >= Motion.tobiLookDuration { self.lookStart = nil }
            }
            apply(pose)
            if idle.sneezes != lastSneeze {
                lastSneeze = idle.sneezes
                spray(at: now)
            }
            moveDroplets(at: now)
            if !playing && blinkStart == nil && lookStart == nil { stop() }
        }

        /// Gotinhas do espirro: saem do nariz pra frente e pros lados, caem e somem.
        /// Ficam no mundo, não no rosto, então a sacudida da cabeça não arrasta elas.
        private func spray(at now: CFTimeInterval) {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: UIColor(red: 0.78, green: 0.9, blue: 1, alpha: 1))
            material.roughness = 0.08
            material.blending = .transparent(opacity: 0.75)
            let mesh = MeshResource.generateSphere(radius: 1)
            let nose = face.convert(position: [0, -0.31, 0.47], to: anchor)
            for _ in 0..<18 {
                let drop = ModelEntity(mesh: mesh, materials: [material])
                let size = Float.random(in: 0.006...0.014)
                let origin = nose + SIMD3(Float.random(in: -0.05...0.05), Float.random(in: -0.03...0.02), 0)
                drop.scale = .init(repeating: size)
                drop.position = origin
                anchor.addChild(drop)
                let velocity = SIMD3(Float.random(in: -1.1...1.1), Float.random(in: -0.3...0.9), Float.random(in: 0.6...1.6))
                droplets.append(Droplet(entity: drop, origin: origin, velocity: velocity, size: size,
                                        born: now, life: Double.random(in: 0.4...0.7)))
            }
        }

        private func moveDroplets(at now: CFTimeInterval) {
            guard !droplets.isEmpty else { return }
            droplets.removeAll { drop in
                let age = now - drop.born
                guard age < drop.life else {
                    drop.entity.removeFromParent()
                    return true
                }
                let t = Float(age)
                drop.entity.position = drop.origin + drop.velocity*t + SIMD3(0, -1.6*t*t, 0)
                // Encolhe no fim da vida em vez de sumir de uma vez.
                drop.entity.scale = .init(repeating: drop.size * Float(1 - pow(age/drop.life, 3)))
                return false
            }
        }

        /// Direção do dedo a partir do rosto. Longe, só a direção conta; perto do focinho,
        /// o alvo encolhe e ele olha pra você.
        private func fingerDirection() -> SIMD2<Float>? {
            guard let view, let point = finger.point else { return nil }
            let local = view.convert(point, from: nil)
            let offset = SIMD2(Float(local.x - view.bounds.midX), Float(view.bounds.midY - local.y))
            return offset / max(simd_length(offset), 160)
        }

        /// Velocidade horizontal do dedo, em larguras de tela por segundo.
        private func fingerSwipe(at now: CFTimeInterval) -> Float {
            guard let point = finger.point, let width = view?.window?.bounds.width, width > 0 else {
                lastFinger = nil
                return 0
            }
            defer { lastFinger = (point, now) }
            guard let last = lastFinger, now > last.time else { return 0 }
            return Float((point.x - last.point.x) / width / (now - last.time))
        }

        private func apply(_ baseline: TobiIdleBehavior.Pose) {
            let pose = eatingTime.map { TobiSnackSequence.pose(baseline, at: $0) } ?? baseline
            // A respiração enche o rosto mais na altura do que na largura, e o levanta junto.
            face.scale = [1 + pose.breath*0.007, 1 + pose.breath*0.016, 1 + pose.breath*0.007]
            face.position.y = pose.lift
            if showsBody {
                body.scale = [1 + pose.breath*0.008, 1, 1 + pose.breath*0.015]
                // Patinhas ficam apoiadas; o rabinho acompanha a alegria discretamente.
                let phase = Float(CACurrentMediaTime()-start)
                let wag = playing && active && !reduced ? sin(phase*7)*0.16 : 0
                tail.orientation = simd_quatf(angle: wag, axis: [0,1,0])
            }
            applySoftParts(pose)
            applyBlink(pose.blink + (1-pose.blink)*pose.cheer)
            for index in sockets.indices {
                sockets[index].position = socketPositions[index] + SIMD3(pose.gazeX, pose.gazeY, 0)
                // Olhos atentos abrem um pouco mais.
                sockets[index].scale = [1 + 0.05*pose.eyeWiden, 1 + 0.1*pose.eyeWiden, 1]
            }
            face.orientation = simd_quatf(angle: pose.headRoll, axis: [0,0,1])
                * simd_quatf(angle: pose.headYaw, axis: [0,1,0])
                * simd_quatf(angle: pose.headPitch, axis: [1,0,0])
        }

        private func applyBlink(_ closed: Float) {
            let steps = TobiFaceLibrary.blinkSteps
            let pose = min(steps, max(0, Int((closed*Float(steps)).rounded())))
            guard pose != lastLidPose else { return }
            lastLidPose = pose
            for index in eyeMeshes.indices {
                guard let mesh = try? TobiFaceLibrary.shared.blinkPose(eyeParts[index], step: pose) else { continue }
                eyeMeshes[index].model?.mesh = mesh
            }
        }
    }
}
