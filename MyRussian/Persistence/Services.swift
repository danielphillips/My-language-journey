import Foundation
import SwiftData
import MyRussianCore

// Thin persistence services. Rules (validation, duplicates, statistics) live in MyRussianCore;
// these types apply them to SwiftData and keep audio files in step with their records.

@MainActor
enum GoalStore {
    /// The single learning goal, created with the initial plan on first use.
    static func currentGoal(in context: ModelContext) -> LearningGoal {
        var descriptor = FetchDescriptor<LearningGoal>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let goal = LearningGoal()
        context.insert(goal)
        try? context.save()
        return goal
    }
}

@MainActor
struct StudyLog {
    let context: ModelContext
    var now: () -> Date = Date.init

    func allSessions() -> [StudySession] {
        (try? context.fetch(FetchDescriptor<StudySession>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
    }

    func statistics(calendar: Calendar) -> StudyStatistics {
        StudyStatistics(sessions: allSessions().map(\.draft), calendar: calendar)
    }

    @discardableResult
    func log(_ draft: StudySessionDraft) throws -> StudySession {
        try StudySessionValidator.validate(draft, against: allSessions().map(\.draft), now: now())
        let session = StudySession(draft: draft, createdAt: now())
        context.insert(session)
        try context.save()
        return session
    }

    func update(_ session: StudySession, with draft: StudySessionDraft) throws {
        let others = allSessions().filter { $0.id != session.id }.map(\.draft)
        try StudySessionValidator.validate(draft, against: others, now: now())
        session.apply(draft)
        try context.save()
    }

    func delete(_ session: StudySession) {
        context.delete(session)
        try? context.save()
    }
}

@MainActor
struct MilestoneStore {
    let context: ModelContext

    func statuses() -> [String: MilestoneStatus] {
        let records = (try? context.fetch(FetchDescriptor<MilestoneRecord>())) ?? []
        return Dictionary(records.map { ($0.milestoneID, $0.status) }, uniquingKeysWith: { latest, _ in latest })
    }

    func setStatus(_ status: MilestoneStatus, for milestone: Milestone, now: Date = .now) {
        let id = milestone.id
        let descriptor = FetchDescriptor<MilestoneRecord>(predicate: #Predicate { $0.milestoneID == id })
        if let record = try? context.fetch(descriptor).first {
            record.status = status
            record.updatedAt = now
        } else {
            context.insert(MilestoneRecord(milestoneID: id, status: status, updatedAt: now))
        }
        try? context.save()
    }
}

enum VocabularyServiceError: Error, Equatable {
    case missingRussian
    case missingMeaning
    case duplicate

    var message: String {
        switch self {
        case .missingRussian: "Enter the Russian word or phrase."
        case .missingMeaning: "Add an English meaning."
        case .duplicate: "This word with this meaning is already in your vocabulary."
        }
    }
}

@MainActor
struct VocabularyService {
    let context: ModelContext
    let audioStore: AudioFileStore
    var now: () -> Date = Date.init

    func allWords() -> [VocabularyWord] {
        (try? context.fetch(FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]))) ?? []
    }

    func duplicateCheck(russian: String, meaning: String, excluding word: VocabularyWord? = nil) -> DuplicateCheck<UUID> {
        VocabularyDuplicateDetector.check(russian: russian, meaning: meaning, among: allWords(), excluding: word?.id)
    }

    // MARK: Words

    @discardableResult
    func addWord(russian: String, meaning: String, confidence: ConfidenceLevel = .learning,
                 example: String = "", notes: String = "",
                 pronunciation: PronunciationNoteDraft? = nil,
                 topic: VocabularyTopic? = nil) throws -> VocabularyWord {
        let (cleanRussian, cleanMeaning) = try validated(russian: russian, meaning: meaning, excluding: nil)
        let word = VocabularyWord(russian: cleanRussian, meaning: cleanMeaning, confidence: confidence, date: now())
        word.example = VocabularyText.cleanedForStorage(example)
        word.notes = VocabularyText.cleanedForStorage(notes)
        word.topic = topic
        context.insert(word)
        if let pronunciation {
            addNote(pronunciation, to: word)
        }
        try context.save()
        return word
    }

    func update(_ word: VocabularyWord, russian: String, meaning: String, example: String, notes: String) throws {
        let (cleanRussian, cleanMeaning) = try validated(russian: russian, meaning: meaning, excluding: word)
        word.russian = cleanRussian
        word.meaning = cleanMeaning
        word.example = VocabularyText.cleanedForStorage(example)
        word.notes = VocabularyText.cleanedForStorage(notes)
        word.dateUpdated = now()
        try context.save()
    }

    func setConfidence(_ confidence: ConfidenceLevel, for word: VocabularyWord) {
        guard word.confidence != confidence else { return }
        word.confidence = confidence
        word.dateUpdated = now()
        try? context.save()
    }

    func setTopic(_ topic: VocabularyTopic?, for word: VocabularyWord) {
        guard word.topic != topic else { return }
        word.topic = topic
        word.dateUpdated = now()
        try? context.save()
    }

    /// Sets or removes the word's photo. Pass already-compressed JPEG data (see `PhotoEncoder`).
    func setPhoto(_ jpeg: Data?, for word: VocabularyWord) {
        word.photoData = jpeg
        word.dateUpdated = now()
        try? context.save()
    }

    func delete(_ word: VocabularyWord) {
        for recording in word.recordings ?? [] {
            try? audioStore.delete(recording.relativePath)
        }
        context.delete(word)
        try? context.save()
    }

    private func validated(russian: String, meaning: String, excluding word: VocabularyWord?) throws -> (String, String) {
        let cleanRussian = VocabularyText.cleanedForStorage(russian)
        let cleanMeaning = VocabularyText.cleanedForStorage(meaning)
        guard !cleanRussian.isEmpty else { throw VocabularyServiceError.missingRussian }
        guard !cleanMeaning.isEmpty else { throw VocabularyServiceError.missingMeaning }
        if duplicateCheck(russian: cleanRussian, meaning: cleanMeaning, excluding: word).blocksSaving {
            throw VocabularyServiceError.duplicate
        }
        return (cleanRussian, cleanMeaning)
    }

    // MARK: Pronunciation notes

    @discardableResult
    func addNote(_ draft: PronunciationNoteDraft, to word: VocabularyWord) -> PronunciationNote {
        let nextIndex = ((word.pronunciationNotes ?? []).map(\.sortIndex).max() ?? -1) + 1
        let note = PronunciationNote(draft: draft, sortIndex: nextIndex, createdAt: now())
        context.insert(note)
        note.word = word
        if word.pronunciationNotes == nil { word.pronunciationNotes = [] }
        if !(word.pronunciationNotes ?? []).contains(where: { $0.id == note.id }) {
            word.pronunciationNotes?.append(note)
        }
        word.dateUpdated = now()
        try? context.save()
        return note
    }

    func updateNote(_ note: PronunciationNote, text: String, language: ReferenceLanguage, explanation: String?) throws {
        let draft = try PronunciationNoteDraft(text: text, language: language, explanation: explanation)
        note.text = draft.text
        note.language = draft.language
        note.explanation = draft.explanation
        note.word?.dateUpdated = now()
        try context.save()
    }

    func deleteNote(_ note: PronunciationNote) {
        note.word?.pronunciationNotes?.removeAll { $0.id == note.id }
        context.delete(note)
        try? context.save()
    }

    /// Most recently used reference languages, newest first, for quick entry.
    func recentLanguages() -> [ReferenceLanguage] {
        var descriptor = FetchDescriptor<PronunciationNote>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 10
        return ((try? context.fetch(descriptor)) ?? []).map(\.language)
    }

    // MARK: Recordings

    @discardableResult
    func addRecording(_ result: RecordingResult, to word: VocabularyWord, title: String? = nil) -> AudioRecording {
        let nextIndex = ((word.recordings ?? []).map(\.sortIndex).max() ?? -1) + 1
        let recording = AudioRecording(result: result, title: title ?? "Take \(nextIndex + 1)", sortIndex: nextIndex)
        context.insert(recording)
        recording.word = word
        if word.recordings == nil { word.recordings = [] }
        if !(word.recordings ?? []).contains(where: { $0.id == recording.id }) {
            word.recordings?.append(recording)
        }
        word.dateUpdated = now()
        try? context.save()
        return recording
    }

    func rename(_ recording: AudioRecording, title: String, annotation: String) {
        let cleanTitle = VocabularyText.cleanedForStorage(title)
        if !cleanTitle.isEmpty { recording.title = cleanTitle }
        recording.annotation = VocabularyText.cleanedForStorage(annotation)
        try? context.save()
    }

    func deleteRecording(_ recording: AudioRecording) {
        try? audioStore.delete(recording.relativePath)
        recording.word?.recordings?.removeAll { $0.id == recording.id }
        context.delete(recording)
        try? context.save()
    }

    func isAvailable(_ recording: AudioRecording) -> Bool {
        audioStore.fileExists(recording.relativePath)
    }

    func url(for recording: AudioRecording) -> URL {
        audioStore.url(for: recording.relativePath)
    }
}
