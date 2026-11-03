import AVFoundation
import Observation

/// Speaks Russian text with the best installed ru-RU system voice (on-device, works offline).
@MainActor
@Observable
final class RussianSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var speakingText: String?
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Prefers premium, then enhanced, then the default Russian voice.
    static let voice: AVSpeechSynthesisVoice? = {
        let russian = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ru-RU" }
        return russian.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "ru-RU")
    }()

    func speak(_ text: String, slow: Bool = true) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.8 : 0.95)
        utterance.preUtteranceDelay = 0
        speakingText = text
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingText = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingText = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingText = nil }
    }
}
