import AVFoundation
import Observation

/// Main-actor facade the UI observes. All audio-session and synthesizer work happens on
/// `SpeechEngine`'s background queue, so taps never block the main thread.
@MainActor
@Observable
final class RussianSpeaker {
    private(set) var speakingText: String?
    @ObservationIgnored private let engine = SpeechEngine()

    init() {
        engine.onFinish = { [weak self] text in
            Task { @MainActor in
                guard let self, self.speakingText == text else { return }
                self.speakingText = nil
            }
        }
    }

    /// Warms up the voice and audio session off the main thread. Call when the screen appears.
    func prepare() {
        engine.prepare()
    }

    func speak(_ text: String, slow: Bool = true) {
        speakingText = text
        engine.speak(text, rate: AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.8 : 0.95))
    }

    func stop() {
        speakingText = nil
        engine.stop()
    }
}

/// Owns the synthesizer on a private serial queue. Rapid requests coalesce: only the most
/// recent one is spoken, stale ones are dropped instead of piling up.
final class SpeechEngine: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (@Sendable (String) -> Void)?

    private let queue = DispatchQueue(label: "MyRussian.speech", qos: .userInitiated)
    private let lock = NSLock()
    private var latestRequest = 0 // guarded by `lock`

    // Accessed only on `queue`.
    private var synthesizer: AVSpeechSynthesizer?
    private var voice: AVSpeechSynthesisVoice?
    private var sessionActive = false

    func prepare() {
        queue.async { self.setUpIfNeeded() }
    }

    func speak(_ text: String, rate: Float) {
        let request = nextRequest()
        queue.async {
            guard self.isLatest(request) else { return } // a newer tap superseded this one
            self.setUpIfNeeded()
            guard let synthesizer = self.synthesizer else { return }
            if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = self.voice
            utterance.rate = rate
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        _ = nextRequest()
        queue.async {
            self.synthesizer?.stopSpeaking(at: .immediate)
            if self.sessionActive {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                self.sessionActive = false
            }
        }
    }

    // MARK: Queue-only helpers

    private func setUpIfNeeded() {
        if synthesizer == nil {
            let synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = self
            self.synthesizer = synthesizer
            // Scanning installed voices is slow; do it once, here, off the main thread.
            let russian = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ru-RU" }
            voice = russian.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "ru-RU")
        }
        let session = AVAudioSession.sharedInstance()
        // Other screens (recording, playback) may have changed the session; only touch it when needed.
        if session.category != .playback || session.mode != .spokenAudio {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            sessionActive = false
        }
        if !sessionActive {
            sessionActive = (try? session.setActive(true)) != nil
        }
    }

    private func nextRequest() -> Int {
        lock.lock(); defer { lock.unlock() }
        latestRequest += 1
        return latestRequest
    }

    private func isLatest(_ request: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return request == latestRequest
    }

    // MARK: AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?(utterance.speechString)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?(utterance.speechString)
    }
}
