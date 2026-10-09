import AVFoundation
import AVKit
import SwiftUI

/// Tela do onboarding antes do paywall: os widgets do Tobi de verdade (o anel enche, o número conta) e o vídeo
/// de como colocar. Saindo do app com o vídeo tocando, ele continua numa janelinha por cima da tela de início.
struct WidgetStep: View {
    let onContinue: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var player = TutorialPlayer()
    @State private var revealed = false
    @State private var snapshot = Self.empty
    /// Tocou em "Colocar o widget": o vídeo vira janelinha e a tela espera a pessoa voltar.
    @State private var placing = false
    /// Saiu do app depois de tocar em colocar; na volta, o botão vira "Pronto".
    @State private var leftToPlace = false
    @State private var cameBack = false

    private static let empty = WidgetSnapshot(day: .now, kcal: 0, carbs: 0, protein: 0, fat: 0, goal: 2000,
                                              carbsShare: 0.5, proteinShare: 0.2, fatShare: 0.3)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Deixa o Tobi na\ntela de início")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Quem coloca o widget tem \(Text("75% mais chance").foregroundStyle(.indigo).fontWeight(.semibold)) de criar o hábito 👀")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .reveal(revealed, order: 0)

            stage
                .frame(maxHeight: .infinity)

            VStack(spacing: 10) {
                Text(hint)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 40)
                    .contentTransition(.opacity)
                Button(action: primary) {
                    Label(cameBack ? "Pronto, coloquei" : "Colocar o widget",
                          systemImage: cameBack ? "checkmark" : "square.grid.2x2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent)
                .tint(.indigo)
                Button("Agora não", action: finish)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(cameBack ? 0 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .reveal(revealed, order: 4)
        }
        .sensoryFeedback(.selection, trigger: placing)
        .sensoryFeedback(.success, trigger: cameBack)
        .task {
            player.play()
            withAnimation(Motion.surface) { revealed = true }
            // Os widgets chegam vazios e enchem com um dia de exemplo, como na tela de início.
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.spring(duration: 1.4, bounce: 0.15)) { snapshot = .sample }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, placing { leftToPlace = true }
            if phase == .active, leftToPlace {
                withAnimation(Motion.surface) { cameBack = true }
            }
        }
        .onDisappear { player.stop() }
    }

    private var hint: String {
        if cameBack { return "Colocou? Agora é só olhar pra tela de início." }
        if placing { return "Vai pra tela de início e segue o vídeo. Ele fica numa janelinha pra te guiar." }
        return "Leva 10 segundos. O vídeo te mostra o caminho."
    }

    /// O vídeo de verdade no meio, os dois widgets flutuando em volta.
    private var stage: some View {
        ZStack {
            TutorialVideo(player: player)
                .aspectRatio(590.0 / 1278.0, contentMode: .fit)
                .frame(height: 330)
                .clipShape(.rect(cornerRadius: 30))
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                .reveal(revealed, order: 1)

            widget(width: 338, height: 158) { MediumDay(snapshot: snapshot) }
                .scaleEffect(0.62)
                .rotationEffect(.degrees(-5))
                .offset(x: -64, y: -118)
                .reveal(revealed, order: 2)

            widget(width: 158, height: 158) { SmallDay(snapshot: snapshot) }
                .scaleEffect(0.74)
                .rotationEffect(.degrees(6))
                .offset(x: 100, y: 104)
                .reveal(revealed, order: 3)
        }
    }

    /// Um widget do jeito que ele aparece na tela de início: a estampa no fundo e os cantos do iOS.
    private func widget<Content: View>(width: CGFloat, height: CGFloat,
                                       @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: width, height: height)
            .background(PatternBackground())
            .clipShape(.rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
    }

    private func primary() {
        if cameBack { return finish() }
        Analytics.track("widget_tutorial_started")
        withAnimation(Motion.surface) { placing = true }
        player.startPictureInPicture()
    }

    private func finish() {
        Analytics.track("widget_step_done", properties: ["colocou": cameBack ? "sim" : "nao"])
        player.stop()
        onContinue()
    }
}

/// O vídeo do tutorial em loop, mudo, pronto pra virar janelinha (picture-in-picture).
@MainActor @Observable
final class TutorialPlayer: NSObject, AVPictureInPictureControllerDelegate {
    @ObservationIgnored let queue = AVQueuePlayer()
    @ObservationIgnored private var looper: AVPlayerLooper?
    @ObservationIgnored private var pip: AVPictureInPictureController?
    @ObservationIgnored private var stopped = false

    override init() {
        super.init()
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false
        if let url = Bundle.main.url(forResource: "widget-tutorial", withExtension: "mp4") {
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        }
    }

    /// A janelinha nasce da camada do vídeo e abre sozinha quando o app vai pro fundo tocando.
    func attach(_ layer: AVPlayerLayer) {
        guard pip == nil, AVPictureInPictureController.isPictureInPictureSupported(),
              let controller = AVPictureInPictureController(playerLayer: layer) else { return }
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        pip = controller
    }

    func play() {
        // A Apple só abre a janelinha com a sessão de reprodução; o vídeo é mudo e não para a música de ninguém.
        // Ligar e desligar a sessão trava a thread de quem chama: fica fora da principal.
        Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try? session.setActive(true)
        }
        queue.play()
    }

    func startPictureInPicture() {
        guard let pip, pip.isPictureInPicturePossible else { return }
        pip.startPictureInPicture()
    }

    /// Para tudo e solta o vídeo da memória: depois do widget o paywall fica sem decodificador ligado.
    func stop() {
        guard !stopped else { return }
        stopped = true
        pip?.stopPictureInPicture()
        pip = nil
        queue.pause()
        looper?.disableLooping()
        looper = nil
        queue.removeAllItems()
        Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

private struct TutorialVideo: UIViewRepresentable {
    let player: TutorialPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player.queue
        view.playerLayer.videoGravity = .resizeAspectFill
        player.attach(view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
