import Accelerate
import AVFoundation

/// Lê o microfone em faixas de frequência da voz (graves à esquerda, agudos à direita), de 0 a 1.
/// Roda na thread do áudio, a cada buffer; quem desenha só lê o resultado.
nonisolated final class VoiceSpectrum: @unchecked Sendable {
    static let bandCount = 5

    private let size = 1024
    private let fft: vDSP.DiscreteFourierTransform<Float>
    private let window: [Float]
    /// Pico recente de cada faixa: o nível é relativo a ele, então funciona com voz baixa ou alta.
    private var peaks = [Float](repeating: 1e-3, count: bandCount)
    private var smoothed = [Float](repeating: 0, count: bandCount)

    init?() {
        guard let fft = try? vDSP.DiscreteFourierTransform(
            count: 1024, direction: .forward, transformType: .complexComplex, ofType: Float.self
        ) else { return nil }
        self.fft = fft
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: 1024, isHalfWindow: false)
    }

    func levels(of buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData?[0], Int(buffer.frameLength) >= size else { return smoothed }
        let samples = Array(UnsafeBufferPointer(start: channel, count: size))

        // Volume geral em dBFS: abaixo de -55 é silêncio, acima de -15 é fala alta.
        let rms = vDSP.rootMeanSquare(samples)
        let loudness = min(max((20 * log10(rms + 1e-7) + 55) / 40, 0), 1)

        let windowed = vDSP.multiply(samples, window)
        let (real, imaginary) = fft.transform(real: windowed, imaginary: [Float](repeating: 0, count: size))
        let magnitudes = zip(real.prefix(size / 2), imaginary.prefix(size / 2)).map { hypotf($0, $1) }

        // Faixas em escala logarítmica entre 90 Hz e 4 kHz, onde mora a voz.
        let binWidth = Float(buffer.format.sampleRate) / Float(size)
        let low: Float = 90, high: Float = 4000
        for band in 0..<Self.bandCount {
            let from = low * pow(high / low, Float(band) / Float(Self.bandCount))
            let to = low * pow(high / low, Float(band + 1) / Float(Self.bandCount))
            let range = max(Int(from / binWidth), 1)..<max(Int(to / binWidth), Int(from / binWidth) + 2)
            let energy = vDSP.mean(Array(magnitudes[range.clamped(to: 1..<magnitudes.count)]))
            peaks[band] = max(peaks[band] * 0.997, energy)
            let level = pow(energy / peaks[band], 0.8) * loudness
            // Sobe rápido, desce devagar: a luz acompanha a sílaba e não pisca.
            smoothed[band] += (level - smoothed[band]) * (level > smoothed[band] ? 0.55 : 0.12)
        }
        return smoothed
    }
}
