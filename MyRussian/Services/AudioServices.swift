import AVFoundation
import Foundation
import Observation
import MyRussianCore

/// Real microphone, via AVAudioRecorder. Only used from the main actor.
final class AVAudioRecorderDevice: NSObject, AudioRecordingDevice, @unchecked Sendable {
    private var recorder: AVAudioRecorder?

    var currentPermission: MicrophonePermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        case .undetermined: .undetermined
        @unknown default: .restricted
        }
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startRecording(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw CocoaError(.fileWriteUnknown)
        }
        self.recorder = recorder
    }

    var currentTime: TimeInterval { recorder?.currentTime ?? 0 }

    func stopRecording() -> TimeInterval {
        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        deactivateSession()
        return duration
    }

    func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        deactivateSession()
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Stand-in microphone for UI tests and the simulator-free CI path: writes a short silent WAV.
final class SimulatedRecordingDevice: AudioRecordingDevice, @unchecked Sendable {
    private var startedAt: Date?
    private var url: URL?

    var currentPermission: MicrophonePermission { .granted }
    func requestPermission() async -> Bool { true }

    func startRecording(to url: URL) throws {
        try Self.silentWAV(seconds: 1).write(to: url)
        self.url = url
        startedAt = .now
    }

    var currentTime: TimeInterval { startedAt.map { Date.now.timeIntervalSince($0) } ?? 0 }

    func stopRecording() -> TimeInterval {
        defer { startedAt = nil; url = nil }
        return max(currentTime, 1)
    }

    func cancelRecording() {
        if let url { try? FileManager.default.removeItem(at: url) }
        startedAt = nil
        url = nil
    }

    static func silentWAV(seconds: Double, sampleRate: Int = 8_000) -> Data {
        let sampleCount = Int(Double(sampleRate) * seconds)
        let dataSize = sampleCount * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(dataSize))
        data.append(Data(count: dataSize))
        return data
    }
}

/// Plays one recording at a time.
@MainActor
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: UUID?
    var errorMessage: String?
    @ObservationIgnored private var player: AVAudioPlayer?

    func toggle(id: UUID, url: URL) {
        if playingID == id {
            stop()
            return
        }
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.play() else { throw CocoaError(.fileReadCorruptFile) }
            self.player = player
            playingID = id
        } catch {
            errorMessage = "This recording can’t be played. The file may be missing or damaged."
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playingID = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.stop()
            self.errorMessage = "This recording can’t be played. The file may be damaged."
        }
    }
}

enum AudioImport {
    /// Reads the duration of an external clip; fails for files AVFoundation can't decode.
    static func duration(of url: URL) async throws -> TimeInterval {
        let duration = try await AVURLAsset(url: url).load(.duration)
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0 else { throw AudioFileStoreError.unsupportedFormat }
        return seconds
    }

    /// Copies a file chosen in the Files picker into app storage.
    static func importClip(from url: URL, store: AudioFileStore) async throws -> RecordingResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let duration = try await duration(of: url)
        return try RecordingFlow.importRecording(from: url, duration: duration, store: store, now: .now)
    }
}
