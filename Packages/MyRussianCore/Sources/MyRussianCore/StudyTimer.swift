import Foundation

public enum StudyCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case duolingo, vocabulary, grammar, listening, speaking, reading, writing, tutoring, other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .duolingo: "Duolingo"
        case .vocabulary: "Vocabulary"
        case .grammar: "Grammar"
        case .listening: "Listening"
        case .speaking: "Speaking"
        case .reading: "Reading"
        case .writing: "Writing"
        case .tutoring: "Tutoring"
        case .other: "Other"
        }
    }

    /// SF Symbol name.
    public var systemImage: String {
        switch self {
        case .duolingo: "bird"
        case .vocabulary: "character.book.closed"
        case .grammar: "textformat.abc"
        case .listening: "headphones"
        case .speaking: "waveform"
        case .reading: "book"
        case .writing: "pencil.line"
        case .tutoring: "person.2"
        case .other: "ellipsis.circle"
        }
    }
}

/// A finished study session, from the live timer or manual entry.
public struct StudySessionDraft: Equatable, Hashable, Sendable {
    public var start: Date
    public var duration: TimeInterval
    public var category: StudyCategory
    public var notes: String

    public init(start: Date, duration: TimeInterval, category: StudyCategory, notes: String = "") {
        self.start = start
        self.duration = duration
        self.category = category
        self.notes = notes
    }

    public var end: Date { start + duration }
}

/// Live study timer. Elapsed time is derived from timestamps rather than ticks, so backgrounding,
/// suspension and termination (with persisted state) never lose or double-count time.
public struct StudyTimer: Codable, Equatable, Sendable {
    public enum State: Codable, Equatable, Sendable {
        case idle
        case running(since: Date)
        case paused
    }

    /// Sessions shorter than this are treated as accidental taps.
    public static let minimumDuration: TimeInterval = 1

    public private(set) var state: State = .idle
    public private(set) var startedAt: Date?
    private var accumulated: TimeInterval = 0
    public var category: StudyCategory
    public var notes: String = ""

    public init(category: StudyCategory = .other) {
        self.category = category
    }

    public var isActive: Bool { state != .idle }

    public mutating func start(at now: Date) {
        guard state == .idle else { return }
        startedAt = now
        accumulated = 0
        state = .running(since: now)
    }

    public mutating func pause(at now: Date) {
        guard case let .running(since) = state else { return }
        accumulated += max(now.timeIntervalSince(since), 0)
        state = .paused
    }

    public mutating func resume(at now: Date) {
        guard state == .paused else { return }
        state = .running(since: now)
    }

    public func elapsed(at now: Date) -> TimeInterval {
        switch state {
        case .idle: 0
        case .paused: accumulated
        case let .running(since): accumulated + max(now.timeIntervalSince(since), 0)
        }
    }

    /// Stops the timer and returns the completed session, or `nil` when nothing meaningful was recorded.
    public mutating func stop(at now: Date) -> StudySessionDraft? {
        let duration = elapsed(at: now)
        let start = startedAt
        let session = StudySessionDraft(start: start ?? now, duration: duration, category: category, notes: notes)
        discard()
        guard start != nil, duration >= Self.minimumDuration else { return nil }
        return session
    }

    public mutating func discard() {
        state = .idle
        startedAt = nil
        accumulated = 0
        notes = ""
    }
}
