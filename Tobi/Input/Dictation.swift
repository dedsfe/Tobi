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
    /// Último passo do ditado ("pedindo permissão", "sem permissão de fala"...). Os testes de
    /// interface leem isso pra saber onde o ditado parou.
    private(set) var step = "parado"
    /// Por que o último ditado não ligou, em palavras pra quem usa. Some no próximo toque.
    private(set) var problem: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private let audio = AudioEngineBox()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Muda a cada `start`, para respostas atrasadas de um ditado antigo não pararem o novo.
    private var sessionID = 0

    func start() async {
        guard !isRecording, !Task.isCancelled else { return }
        // A tela responde no toque; permissão e áudio sobem por trás. Se não der, volta.
        isRecording = true
        problem = nil
        step = "pedindo permissão"
        sessionID += 1
        let id = sessionID
        let permissions = await Self.requestPermissions()
        guard permissions.speech else { return fail("sem permissão de fala", id) }
        guard permissions.microphone else { return fail("sem permissão de microfone", id) }
        guard let recognizer else { return fail("sem reconhecedor pt-BR", id) }
        guard recognizer.isAvailable else { return fail("reconhecedor indisponível", id) }
        // Parou enquanto pedia permissão.
        guard isRecording, sessionID == id, !Task.isCancelled else {
            if sessionID == id { stop() }
            return
        }

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
            guard isRecording, sessionID == id, !Task.isCancelled else {
                if sessionID == id { stop() }
                return
            }
            step = "ouvindo"

            self.request = request
            task = Self.recognize(request, with: recognizer) { [weak self] text, isDone in
                guard let self, self.sessionID == id, self.isRecording else { return }
                if let text { transcript = text }
                if isDone { stop() }
            }
        } catch {
            fail("áudio não ligou: \(error.localizedDescription) (\((error as NSError).code))", id)
        }
    }

    private func fail(_ reason: String, _ id: Int) {
        guard sessionID == id else { return }
        stop()
        step = reason
        problem = switch reason {
        case "sem permissão de fala", "sem permissão de microfone":
            "Libere o microfone e o reconhecimento de fala em Ajustes > Tobi."
        case "sem reconhecedor pt-BR", "reconhecedor indisponível":
            "O ditado em português não está disponível agora."
        case let reason where reason.contains("561017449"):
            // AVAudioSession.ErrorCode.insufficientPriority: outro áudio tem a vez.
            "Outro app está usando o microfone (gravação de tela, ligação ou música). Fecha ele e tenta de novo."
        default:
            "Não consegui ligar o microfone. Tenta de novo."
        }
    }

    func stop() {
        sessionID += 1
        audio.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        levels = levels.map { _ in 0 }
        step = "parado"
    }

    // As closures abaixo rodam fora da main thread, então nascem em funções nonisolated.

    private nonisolated static func requestPermissions() async -> (speech: Bool, microphone: Bool) {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return (false, false) }
        return (true, await AVAudioApplication.requestRecordPermission())
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
    private var sessionActive = false

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
        try activateSession()
        sessionActive = true
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate.isFinite, format.sampleRate > 0, format.channelCount > 0 else {
            throw CocoaError(.featureUnsupported)
        }
        let spectrum = VoiceSpectrum()
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            append(buffer)
            if let spectrum { levels(spectrum.levels(of: buffer)) }
        }
        tapped = true
        engine.prepare()
        try engine.start()
    }

    /// Ligar a sessão às vezes falha de primeira (o sistema ainda está soltando a anterior, ou
    /// outro áudio tem prioridade). Tenta de novo com uma pausa curta e, se ainda assim não der,
    /// cai pra gravar-e-tocar, que convive melhor com o resto do sistema.
    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        let setups: [(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)] = [
            (.record, .measurement, [.duckOthers]),
            (.record, .measurement, [.duckOthers]),
            (.playAndRecord, .default, [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]),
        ]
        var lastError: Error?
        for (attempt, setup) in setups.enumerated() {
            do {
                try session.setCategory(setup.0, mode: setup.1, options: setup.2)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                return
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: 0.12 * Double(attempt + 1))
            }
        }
        throw lastError ?? CocoaError(.featureUnsupported)
    }

    private func stopNow() {
        if tapped {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            tapped = false
        }
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }
}
