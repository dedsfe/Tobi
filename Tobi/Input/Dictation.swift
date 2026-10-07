import AVFoundation
import Speech

/// Ditado em português: fala "dois ovos e um pão" e o texto aparece na linha.
@MainActor @Observable
final class Dictation {
    private(set) var isRecording = false
    /// Tudo que foi falado desde o último `start`.
    private(set) var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Muda a cada `start`, para respostas atrasadas de um ditado antigo não pararem o novo.
    private var sessionID = 0

    func start() async {
        guard !isRecording, await Self.requestPermissions(),
              let recognizer, recognizer.isAvailable else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = false
            Self.installTap(on: engine.inputNode, feeding: request)
            engine.prepare()
            try engine.start()

            self.request = request
            transcript = ""
            sessionID += 1
            let id = sessionID
            task = Self.recognize(request, with: recognizer) { [weak self] text, isDone in
                guard let self, self.sessionID == id else { return }
                if let text { transcript = text }
                if isDone { stop() }
            }
            isRecording = true
        } catch {
            stop()
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // As closures abaixo rodam fora da main thread, então nascem em funções nonisolated.

    private nonisolated static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private nonisolated static func installTap(on node: AVAudioInputNode,
                                               feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
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
