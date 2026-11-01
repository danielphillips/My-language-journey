import Foundation
import Observation

// MARK: - Metadata

/// Personal recordings are distinguishable from future native-speaker reference audio.
public enum AudioKind: String, Codable, Sendable {
    case personal
    case reference
}

public enum AudioSource: String, Codable, Sendable {
    case recorded
    case imported
}

/// Metadata for a newly captured or imported clip. The audio itself lives on disk;
/// only the relative path is persisted.
public struct RecordingResult: Equatable, Sendable {
    public let id: UUID
    public let relativePath: String
    public let duration: TimeInterval
    public let createdAt: Date
    public let kind: AudioKind
    public let source: AudioSource

    public init(id: UUID, relativePath: String, duration: TimeInterval, createdAt: Date,
                kind: AudioKind, source: AudioSource) {
        self.id = id
        self.relativePath = relativePath
        self.duration = duration
        self.createdAt = createdAt
        self.kind = kind
        self.source = source
    }
}

// MARK: - File storage

public enum AudioFileStoreError: Error, Equatable, Sendable {
    case unsupportedFormat
    case fileTooLarge
    case sourceMissing
    case invalidPath

    public var message: String {
        switch self {
        case .unsupportedFormat: "That file isn’t a supported audio format."
        case .fileTooLarge: "That clip is too large. Short clips work best."
        case .sourceMissing: "The file couldn’t be found."
        case .invalidPath: "That recording can’t be accessed."
        }
    }
}

/// Stores audio files flat in one app-managed directory, addressed by relative path.
public struct AudioFileStore: Sendable {
    public static let supportedExtensions: Set<String> = ["m4a", "mp3", "wav", "aac", "caf", "aif", "aiff"]
    public static let defaultMaximumImportBytes = 50 * 1024 * 1024

    public let directory: URL
    public let maximumImportBytes: Int

    public init(directory: URL, maximumImportBytes: Int = AudioFileStore.defaultMaximumImportBytes) throws {
        self.directory = directory
        self.maximumImportBytes = maximumImportBytes
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func newRecordingLocation() -> (relativePath: String, url: URL) {
        let relativePath = "\(UUID().uuidString).m4a"
        return (relativePath, url(for: relativePath))
    }

    public func url(for relativePath: String) -> URL {
        directory.appendingPathComponent(relativePath, isDirectory: false)
    }

    public func fileExists(_ relativePath: String) -> Bool {
        Self.isValid(relativePath) && FileManager.default.fileExists(atPath: url(for: relativePath).path)
    }

    /// Copies an external clip into app storage under a new name.
    public func importAudio(from source: URL) throws -> (relativePath: String, byteCount: Int) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path) else { throw AudioFileStoreError.sourceMissing }
        let fileExtension = source.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(fileExtension) else { throw AudioFileStoreError.unsupportedFormat }
        let size = (try fileManager.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size <= maximumImportBytes else { throw AudioFileStoreError.fileTooLarge }

        let relativePath = "\(UUID().uuidString).\(fileExtension)"
        try fileManager.copyItem(at: source, to: url(for: relativePath))
        return (relativePath, size)
    }

    /// Removes a stored file. Deleting a file that is already gone is not an error.
    public func delete(_ relativePath: String) throws {
        guard Self.isValid(relativePath) else { throw AudioFileStoreError.invalidPath }
        let target = url(for: relativePath)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }

    /// Files on disk that no recording refers to, e.g. after a crash mid-save.
    public func orphanedFiles(referenced: Set<String>) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { !$0.hasPrefix(".") && !referenced.contains($0) }.sorted()
    }

    static func isValid(_ relativePath: String) -> Bool {
        !relativePath.isEmpty && !relativePath.contains("/") && !relativePath.contains("\\")
            && !relativePath.hasPrefix(".")
    }
}

// MARK: - Recording

public enum MicrophonePermission: Sendable {
    case undetermined, granted, denied, restricted
}

/// Hardware boundary for recording. Implemented with AVFoundation in the app and faked in tests.
public protocol AudioRecordingDevice: AnyObject, Sendable {
    var currentPermission: MicrophonePermission { get }
    func requestPermission() async -> Bool
    func startRecording(to url: URL) throws
    /// Seconds recorded so far.
    var currentTime: TimeInterval { get }
    /// Stops and returns the recorded duration in seconds.
    func stopRecording() -> TimeInterval
    /// Stops and abandons the recording.
    func cancelRecording()
}

@MainActor
@Observable
public final class RecordingFlow {
    public enum State: Equatable, Sendable {
        case idle
        case requestingPermission
        case recording(startedAt: Date)
        case permissionDenied
        case failed(String)
    }

    /// Takes shorter than this are treated as accidental taps.
    public static let minimumDuration: TimeInterval = 0.5

    public private(set) var state: State = .idle
    private let device: any AudioRecordingDevice
    private let store: AudioFileStore
    private let now: () -> Date
    private var pending: (relativePath: String, url: URL)?

    public init(device: any AudioRecordingDevice, store: AudioFileStore, now: @escaping () -> Date = Date.init) {
        self.device = device
        self.store = store
        self.now = now
    }

    public var isRecording: Bool {
        if case .recording = state { true } else { false }
    }

    public var elapsed: TimeInterval { isRecording ? device.currentTime : 0 }

    public func start() async {
        guard !isRecording, state != .requestingPermission else { return }

        switch device.currentPermission {
        case .granted:
            break
        case .denied, .restricted:
            state = .permissionDenied
            return
        case .undetermined:
            state = .requestingPermission
            guard await device.requestPermission() else {
                state = .permissionDenied
                return
            }
        }

        let location = store.newRecordingLocation()
        do {
            try device.startRecording(to: location.url)
            pending = location
            state = .recording(startedAt: now())
        } catch {
            try? store.delete(location.relativePath)
            state = .failed("Recording couldn’t start. Please try again.")
        }
    }

    /// Stops and returns the saved take, or `nil` if nothing worth keeping was recorded.
    public func stop() -> RecordingResult? {
        guard case let .recording(startedAt) = state, let location = pending else { return nil }
        let duration = device.stopRecording()
        pending = nil
        state = .idle
        guard duration >= Self.minimumDuration, store.fileExists(location.relativePath) else {
            try? store.delete(location.relativePath)
            return nil
        }
        return RecordingResult(id: UUID(), relativePath: location.relativePath, duration: duration,
                               createdAt: startedAt, kind: .personal, source: .recorded)
    }

    public func cancel() {
        guard isRecording, let location = pending else { return }
        device.cancelRecording()
        try? store.delete(location.relativePath)
        pending = nil
        state = .idle
    }

    /// A system interruption (call, Siri, route loss) ends the take; keep it if it's meaningful.
    public func handleInterruption() -> RecordingResult? {
        stop()
    }

    public func acknowledgeError() {
        if case .failed = state { state = .idle }
        if state == .permissionDenied { state = .idle }
    }

    /// Pure file work, so it can run off the main actor (e.g. after an async duration probe).
    nonisolated public static func importRecording(from source: URL, duration: TimeInterval, store: AudioFileStore,
                                       now: Date) throws -> RecordingResult {
        let stored = try store.importAudio(from: source)
        return RecordingResult(id: UUID(), relativePath: stored.relativePath, duration: duration,
                               createdAt: now, kind: .personal, source: .imported)
    }
}
