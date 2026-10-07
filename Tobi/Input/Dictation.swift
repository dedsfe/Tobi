import AVFoundation
import Speech

/// Ditado em português: fala "dois ovos e um pão" e o texto aparece na linha.
@MainActor @Observable
final class Dictation {
    private(set) var isRecording = false
    /// Tudo que foi falado desde o último `start`.
    private(set) var transcript = ""
    /// Energia da voz por faixa de frequência (0 a 1), atualizada ~40 vezes por segundo.
    /// Só a animação lê isso: quem não desenha não deve observar, pra não redesenhar a tela toda.
    private(set) var levels = [Float](repeating: 0, count: VoiceSpectrum.bandCount)

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private let audio = AudioEngineBox()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Muda a cada `start`, para respostas atrasadas de um ditado antigo não pararem o novo.
    private var sessionID = 0

    func start() async {
        guard !isRecording else { return }
        // A tela responde no toque; permissão e áudio sobem por trás. Se não der, volta.
        isRecording = true
        sessionID += 1
        let id = sessionID
        guard await Self.requestPermissions(), let recognizer, recognizer.isAvailable else {
            if sessionID == id { stop() }
            return
        }
        // Parou enquanto pedia permissão.
        guard isRecording, sessionID == id else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        transcript = ""
        do {
            // Ligar a sessão de áudio trava a thread por centenas de ms: fora da main, a animação
            // de abrir não engasga.
            // O pedido de reconhecimento aceita buffers de qualquer thread (é assim que a Apple usa).
            nonisolated(unsafe) let feed = request
            try await audio.start { buffer in
                feed.append(buffer)
            } levels: { [weak self] levels in
                Task { @MainActor in
                    guard let self, self.sessionID == id, self.isRecording else { return }
                    self.levels = levels
                }
            }
            // Parou enquanto o áudio ligava.
            guard isRecording, sessionID == id else { return }

            self.request = request
            task = Self.recognize(request, with: recognizer) { [weak self] text, isDone in
                guard let self, self.sessionID == id else { return }
                if let text { transcript = text }
                if isDone { stop() }
            }
        } catch {
            stop()
        }
    }

    func stop() {
        audio.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        levels = levels.map { _ in 0 }
    }

    // As closures abaixo rodam fora da main thread, então nascem em funções nonisolated.

    private nonisolated static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private nonisolated static func recognize(
        _ request: SFSpeechAudioBufferRecognitionRequest,
        with recognizer: SFSpeechRecognizer,
        update: @escaping @MainActor @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let isDone = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in update(text, isDone) }
        }
    }
}

/// O motor de áudio vive numa fila própria: ligar e desligar a sessão trava a thread por
/// centenas de ms, então nada disso roda na main. A fila é serial, então um "para" logo depois
/// de um "liga" sempre acontece depois dele.
private nonisolated final class AudioEngineBox: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "tobi.dictation.audio", qos: .userInitiated)
    private var tapped = false

    func start(feeding append: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
               levels: @escaping @Sendable ([Float]) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.startNow(append, levels)
                    continuation.resume()
                } catch {
                    self.stopNow()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async { self.stopNow() }
    }

    private func startNow(_ append: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
                          _ levels: @escaping @Sendable ([Float]) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        let node = engine.inputNode
        let spectrum = VoiceSpectrum()
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in
            append(buffer)
            if let spectrum { levels(spectrum.levels(of: buffer)) }
        }
        tapped = true
        engine.prepare()
        try engine.start()
    }

    private func stopNow() {
        guard tapped else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        tapped = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
