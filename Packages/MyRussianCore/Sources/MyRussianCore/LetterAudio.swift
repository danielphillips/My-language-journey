import Foundation

/// What a personal alphabet recording is of. Raw values are persisted.
public enum LetterAudioKind: String, CaseIterable, Codable, Sendable {
    case letterName = "letter"
    case exampleWord = "example"
}

public struct LetterAudioKey: Hashable, Sendable {
    public let letterID: String
    public let kind: LetterAudioKind

    public init(letterID: String, kind: LetterAudioKind) {
        self.letterID = letterID
        self.kind = kind
    }
}

public enum LetterPlayback: Equatable, Sendable {
    case personal
    case synthesized
}

/// Which alphabet sounds you've recorded yourself. Pass only recordings whose files exist.
public struct LetterAudioLibrary: Sendable {
    private let recorded: Set<LetterAudioKey>

    public init(recorded: [LetterAudioKey]) {
        self.recorded = Set(recorded)
    }

    public func has(_ letterID: String, _ kind: LetterAudioKind) -> Bool {
        recorded.contains(LetterAudioKey(letterID: letterID, kind: kind))
    }

    /// Your voice by default when you've recorded it; the synthetic voice otherwise, or on request.
    public func playback(for letterID: String, _ kind: LetterAudioKind, preferSyntheticVoice: Bool = false) -> LetterPlayback {
        !preferSyntheticVoice && has(letterID, kind) ? .personal : .synthesized
    }

    /// Letters whose name you've recorded get the gold outline.
    public func hasRecordedName(_ letterID: String) -> Bool {
        has(letterID, .letterName)
    }

    public var recordedNameCount: Int {
        recorded.filter { $0.kind == .letterName }.count
    }
}
