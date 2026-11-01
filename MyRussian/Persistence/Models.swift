import Foundation
import SwiftData
import MyRussianCore

// CloudKit-ready by construction: every attribute has a default, every relationship is optional
// with an explicit inverse, and there are no unique constraints. Sync stays off for V1
// (`cloudKitDatabase: .none`); enabling it later needs no migration.

@Model
final class LearningGoal {
    var levelRaw: String = ProficiencyLevel.a1.rawValue
    var examYear: Int = 2027
    var examMonth: Int = 5
    /// Set once the exact exam day is known; otherwise planning is month-level.
    var examExactDate: Date?
    var weeklyTargetHours: Double = 7
    var estimatedHours: Double = 110
    var hasCompletedOnboarding: Bool = false
    var createdAt: Date = Date.now

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }

    var settings: GoalSettings {
        get {
            GoalSettings(
                level: ProficiencyLevel(rawValue: levelRaw) ?? .a1,
                examDate: examExactDate.map { .day($0) } ?? .month(year: examYear, month: examMonth),
                weeklyTargetHours: weeklyTargetHours,
                estimatedHours: estimatedHours
            )
        }
        set {
            levelRaw = newValue.level.rawValue
            switch newValue.examDate {
            case let .month(year, month):
                examYear = year
                examMonth = month
                examExactDate = nil
            case let .day(date):
                let components = Calendar.current.dateComponents([.year, .month], from: date)
                examYear = components.year ?? examYear
                examMonth = components.month ?? examMonth
                examExactDate = date
            }
            weeklyTargetHours = newValue.weeklyTargetHours
            estimatedHours = newValue.estimatedHours
        }
    }
}

@Model
final class StudySession {
    var id: UUID = UUID()
    var start: Date = Date.now
    /// Seconds.
    var duration: Double = 0
    var categoryRaw: String = StudyCategory.other.rawValue
    var notes: String = ""
    var createdAt: Date = Date.now

    init(draft: StudySessionDraft, createdAt: Date = .now) {
        self.createdAt = createdAt
        apply(draft)
    }

    var category: StudyCategory {
        get { StudyCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var end: Date { start + duration }

    var draft: StudySessionDraft {
        StudySessionDraft(start: start, duration: duration, category: category, notes: notes)
    }

    func apply(_ draft: StudySessionDraft) {
        start = draft.start
        duration = draft.duration
        category = draft.category
        notes = draft.notes
    }
}

/// The user's status for one milestone. Milestone definitions live in `MilestoneCatalog`.
@Model
final class MilestoneRecord {
    var milestoneID: String = ""
    var statusRaw: String = MilestoneStatus.notStarted.rawValue
    var updatedAt: Date = Date.now

    init(milestoneID: String, status: MilestoneStatus, updatedAt: Date = .now) {
        self.milestoneID = milestoneID
        self.statusRaw = status.rawValue
        self.updatedAt = updatedAt
    }

    var status: MilestoneStatus {
        get { MilestoneStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class VocabularyWord {
    var id: UUID = UUID()
    var russian: String = ""
    var meaning: String = ""
    var confidenceRaw: Int = ConfidenceLevel.learning.rawValue
    var example: String = ""
    var notes: String = ""
    var dateAdded: Date = Date.now
    var dateUpdated: Date = Date.now
    /// Optional everyday topic (`VocabularyTopic` raw value). Added after V1; optional, so existing stores migrate automatically.
    var topicRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \PronunciationNote.word)
    var pronunciationNotes: [PronunciationNote]? = []

    @Relationship(deleteRule: .cascade, inverse: \AudioRecording.word)
    var recordings: [AudioRecording]? = []

    init(russian: String, meaning: String, confidence: ConfidenceLevel, date: Date) {
        self.russian = russian
        self.meaning = meaning
        self.confidenceRaw = confidence.rawValue
        self.dateAdded = date
        self.dateUpdated = date
    }

    var confidence: ConfidenceLevel {
        get { ConfidenceLevel(rawValue: confidenceRaw) ?? .learning }
        set { confidenceRaw = newValue.rawValue }
    }

    var topic: VocabularyTopic? {
        get { topicRaw.flatMap(VocabularyTopic.init(rawValue:)) }
        set { topicRaw = newValue?.rawValue }
    }

    var sortedPronunciationNotes: [PronunciationNote] {
        (pronunciationNotes ?? []).sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    var sortedRecordings: [AudioRecording] {
        (recordings ?? []).sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }
}

extension VocabularyWord: VocabularyItem {
    var pronunciationTexts: [String] { (pronunciationNotes ?? []).map(\.text) }
}

@Model
final class PronunciationNote {
    var id: UUID = UUID()
    /// Stored verbatim. Never trimmed, corrected or normalised.
    var text: String = ""
    var languageRaw: String = ReferenceLanguage.french.rawValue
    var explanation: String?
    var sortIndex: Int = 0
    var createdAt: Date = Date.now
    var word: VocabularyWord?

    init(draft: PronunciationNoteDraft, sortIndex: Int, createdAt: Date) {
        self.text = draft.text
        self.languageRaw = draft.language.rawValue
        self.explanation = draft.explanation
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var language: ReferenceLanguage {
        get { ReferenceLanguage(rawValue: languageRaw) ?? .french }
        set { languageRaw = newValue.rawValue }
    }

    var flag: String { language.flag }
}

@Model
final class AudioRecording {
    var id: UUID = UUID()
    var title: String = ""
    var annotation: String = ""
    /// File name inside the app's recordings directory. Audio data is never stored in SwiftData.
    var relativePath: String = ""
    var duration: Double = 0
    var sortIndex: Int = 0
    var createdAt: Date = Date.now
    /// `personal` for the learner's own voice; `reference` is reserved for future native audio.
    var kindRaw: String = AudioKind.personal.rawValue
    var sourceRaw: String = AudioSource.recorded.rawValue
    var word: VocabularyWord?

    init(result: RecordingResult, title: String, sortIndex: Int) {
        self.id = result.id
        self.title = title
        self.relativePath = result.relativePath
        self.duration = result.duration
        self.createdAt = result.createdAt
        self.kindRaw = result.kind.rawValue
        self.sourceRaw = result.source.rawValue
        self.sortIndex = sortIndex
    }

    var kind: AudioKind { AudioKind(rawValue: kindRaw) ?? .personal }
    var source: AudioSource { AudioSource(rawValue: sourceRaw) ?? .recorded }
}
