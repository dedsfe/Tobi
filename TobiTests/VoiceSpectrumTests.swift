import AVFoundation
import Testing
@testable import Tobi

struct VoiceSpectrumTests {
    /// 1024 amostras de um tom puro, como o microfone entregaria.
    private func tone(_ hertz: Double, amplitude: Float) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        for i in 0..<1024 {
            buffer.floatChannelData![0][i] = amplitude * Float(sin(2 * .pi * hertz * Double(i) / 44_100))
        }
        return buffer
    }

    @Test func lowVoiceLightsTheLeftBandAndHighVoiceTheRight() throws {
        let low = try #require(VoiceSpectrum())
        let lowLevels = (0..<10).map { _ in low.levels(of: tone(150, amplitude: 0.3)) }.last!
        #expect(lowLevels.firstIndex(of: lowLevels.max()!) == 0)

        let high = try #require(VoiceSpectrum())
        let highLevels = (0..<10).map { _ in high.levels(of: tone(2_500, amplitude: 0.3)) }.last!
        #expect(highLevels.firstIndex(of: highLevels.max()!) == 4)
    }

    @Test func silenceStaysDark() throws {
        let spectrum = try #require(VoiceSpectrum())
        let levels = (0..<10).map { _ in spectrum.levels(of: tone(300, amplitude: 0.0005)) }.last!
        #expect(levels.allSatisfy { $0 < 0.05 })
    }
}
