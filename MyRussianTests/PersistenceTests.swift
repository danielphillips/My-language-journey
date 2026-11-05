import Foundation
import SwiftData
import UIKit
import Testing
import MyRussianCore
@testable import MyRussian

/// Integration tests against real SwiftData (isolated in-memory containers) and real files (temporary directories).
@MainActor
struct TestEnvironment {
    let container: ModelContainer
    let context: ModelContext
    let audioStore: AudioFileStore
    var now: Date

    init(inMemory: Bool = true, storeURL: URL? = nil, audioDirectory: URL? = nil,
         now: Date = Date(timeIntervalSince1970: 1_793_000_000)) throws {
        container = try AppModelContainer.make(inMemory: inMemory, url: storeURL)
        context = container.mainContext
        let directory = audioDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("MyRussianAppTests-\(UUID().uuidString)")
        audioStore = try AudioFileStore(directory: directory)
        self.now = now
    }

    var vocabulary: VocabularyService { VocabularyService(context: context, audioStore: audioStore, now: { now }) }
    var studyLog: StudyLog { StudyLog(context: context, now: { now }) }
}

@MainActor
@Suite("Goal persistence")
struct GoalPersistenceTests {
    @Test func initialGoalIsCreatedOnceWithThePersonalPlan() throws {
        let env = try TestEnvironment()
        let goal = GoalStore.currentGoal(in: env.context)
        let again = GoalStore.currentGoal(in: env.context)
        #expect(goal.persistentModelID == again.persistentModelID)
        #expect(goal.settings == .initial)
        #expect(try env.context.fetchCount(FetchDescriptor<LearningGoal>()) == 1)
    }

    @Test func changingLevelAndExamDatePersists() throws {
        let env = try TestEnvironment()
        let goal = GoalStore.currentGoal(in: env.context)
        var settings = goal.settings
        settings.changeLevel(to: .a2)
        settings.examDate = .day(Date(timeIntervalSince1970: 1_810_000_000))
        settings.weeklyTargetHours = 5
        goal.settings = settings
        try env.context.save()

        let reloaded = GoalStore.currentGoal(in: ModelContext(env.container))
        #expect(reloaded.settings == settings)
    }

    @Test func monthOnlyExamDateRoundTrips() throws {
        let env = try TestEnvironment()
        let goal = GoalStore.currentGoal(in: env.context)
        goal.settings.examDate = .month(year: 2027, month: 6)
        #expect(goal.settings.examDate == .month(year: 2027, month: 6))
    }
}

@MainActor
@Suite("Study log persistence")
struct StudyLogPersistenceTests {
    @Test func loggedSessionsCountTowardsTotals() throws {
        let env = try TestEnvironment()
        try env.studyLog.log(StudySessionDraft(start: env.now - 7200, duration: 3600, category: .grammar, notes: "Cases"))
        try env.studyLog.log(StudySessionDraft(start: env.now - 3600, duration: 1800, category: .duolingo))
        let sessions = env.studyLog.allSessions()
        #expect(sessions.count == 2)
        #expect(env.studyLog.statistics(calendar: .current).totalDuration == 5400)
        #expect(sessions.first?.category == .duolingo, "Most recent first")
    }

    @Test func invalidOrDuplicateSessionsAreNotSaved() throws {
        let env = try TestEnvironment()
        let draft = StudySessionDraft(start: env.now - 3600, duration: 1800, category: .reading)
        try env.studyLog.log(draft)
        #expect(throws: StudySessionValidationError.duplicate) { try env.studyLog.log(draft) }
        #expect(throws: StudySessionValidationError.durationTooShort) {
            try env.studyLog.log(StudySessionDraft(start: env.now - 100, duration: 0, category: .reading))
        }
        #expect(env.studyLog.allSessions().count == 1)
    }

    @Test func editingASessionIsValidatedAgainstOthersOnly() throws {
        let env = try TestEnvironment()
        let session = try env.studyLog.log(StudySessionDraft(start: env.now - 7200, duration: 1800, category: .reading))
        var edited = session.draft
        edited.duration = 2400
        edited.category = .listening
        try env.studyLog.update(session, with: edited)
        #expect(session.duration == 2400)
        #expect(session.category == .listening)
    }

    @Test func deletingASessionRemovesItFromTotals() throws {
        let env = try TestEnvironment()
        let session = try env.studyLog.log(StudySessionDraft(start: env.now - 7200, duration: 1800, category: .reading))
        env.studyLog.delete(session)
        #expect(env.studyLog.allSessions().isEmpty)
        #expect(env.studyLog.statistics(calendar: .current).totalDuration == 0)
    }
}

@MainActor
@Suite("Milestone persistence")
struct MilestonePersistenceTests {
    @Test func statusChangesArePersistedByMilestoneID() throws {
        let env = try TestEnvironment()
        let milestone = MilestoneCatalog.milestones(for: .a1)[0]
        let store = MilestoneStore(context: env.context)
        #expect(store.statuses()[milestone.id] == nil)
        store.setStatus(.learning, for: milestone)
        store.setStatus(.demonstrated, for: milestone)
        #expect(MilestoneStore(context: ModelContext(env.container)).statuses()[milestone.id] == .demonstrated)
        #expect(try env.context.fetchCount(FetchDescriptor<MilestoneRecord>()) == 1)
    }
}

@MainActor
@Suite("Vocabulary persistence")
struct VocabularyPersistenceTests {
    @Test func addingAWordPreservesCyrillicAndStartsAtLearning() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "  Здра́вствуйте ", meaning: "Hello (formal)")
        #expect(word.russian == "Здра́вствуйте")
        #expect(word.confidence == .learning)
        #expect(word.dateAdded == env.now)
        #expect(env.vocabulary.allWords().count == 1)
    }

    @Test func emptyFieldsAreRejected() throws {
        let env = try TestEnvironment()
        #expect(throws: VocabularyServiceError.missingRussian) { try env.vocabulary.addWord(russian: " ", meaning: "x") }
        #expect(throws: VocabularyServiceError.missingMeaning) { try env.vocabulary.addWord(russian: "где", meaning: "") }
    }

    @Test func duplicatesAreBlockedButOtherMeaningsAreAllowed() throws {
        let env = try TestEnvironment()
        try env.vocabulary.addWord(russian: "мир", meaning: "peace")
        #expect(throws: VocabularyServiceError.duplicate) { try env.vocabulary.addWord(russian: "Мир", meaning: "Peace") }
        try env.vocabulary.addWord(russian: "мир", meaning: "world")
        #expect(env.vocabulary.allWords().count == 2)
    }

    @Test func confidenceChangesUpdateTheTimestamp() throws {
        var env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        env.now += 60
        env.vocabulary.setConfidence(.comfortable, for: word)
        #expect(word.confidence == .comfortable)
        #expect(word.dateUpdated == env.now)
        #expect(VocabularyStatistics(items: env.vocabulary.allWords()).count(of: .comfortable) == 1)
    }

    @Test func editingAWordRechecksDuplicatesExcludingItself() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        try env.vocabulary.update(word, russian: "где", meaning: "where", example: "Где метро?", notes: "Very common")
        #expect(word.example == "Где метро?")
        try env.vocabulary.addWord(russian: "куда", meaning: "where to")
        #expect(throws: VocabularyServiceError.duplicate) {
            try env.vocabulary.update(word, russian: "куда", meaning: "where to", example: "", notes: "")
        }
    }

    @Test func topicIsSavedWithTheWordAndCanBeChanged() throws {
        var env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "хлеб", meaning: "bread", topic: .food)
        #expect(word.topic == .food)
        let untopiced = try env.vocabulary.addWord(russian: "где", meaning: "where")
        #expect(untopiced.topic == nil)

        env.now += 60
        env.vocabulary.setTopic(.essentials, for: untopiced)
        #expect(untopiced.topic == .essentials)
        #expect(untopiced.dateUpdated == env.now)
        env.vocabulary.setTopic(nil, for: word)
        #expect(word.topic == nil)

        let breakdown = VocabularyStatistics(items: env.vocabulary.allWords()).topicBreakdown
        #expect(breakdown.map(\.topic) == [.essentials, nil])
    }

    @Test func searchAndFilterWorkOnPersistedWords() throws {
        let env = try TestEnvironment()
        let где = try env.vocabulary.addWord(russian: "где", meaning: "where")
        try env.vocabulary.addNote(try PronunciationNoteDraft(text: "Kadé", language: .french), to: где)
        try env.vocabulary.addWord(russian: "женщины", meaning: "women")
        #expect(VocabularyQuery(searchText: "kade").apply(to: env.vocabulary.allWords()).map(\.russian) == ["где"])
    }
}

@MainActor
@Suite("Pronunciation note persistence")
struct PronunciationNotePersistenceTests {
    @Test func multipleNotesWithIndependentLanguagesAndExactText() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "женщины", meaning: "women")
        try env.vocabulary.addNote(try PronunciationNoteDraft(text: "Gente-chima", language: .brazilianPortuguese), to: word)
        try env.vocabulary.addNote(try PronunciationNoteDraft(text: "Jène-chi-ni", language: .french, explanation: "Soft ж"), to: word)

        let notes = word.sortedPronunciationNotes
        #expect(notes.map(\.text) == ["Gente-chima", "Jène-chi-ni"])
        #expect(notes.map(\.language) == [.brazilianPortuguese, .french])
        #expect(notes.map(\.flag) == ["🇧🇷", "🇫🇷"])
        #expect(notes[1].explanation == "Soft ж")
        #expect(notes.allSatisfy { $0.word?.persistentModelID == word.persistentModelID })
    }

    @Test func editingAndDeletingIndividualNotes() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        let first = try env.vocabulary.addNote(try PronunciationNoteDraft(text: "Kadé", language: .french), to: word)
        let second = try env.vocabulary.addNote(try PronunciationNoteDraft(text: "Gdyeh", language: .english), to: word)

        try env.vocabulary.updateNote(first, text: "Gdé", language: .brazilianPortuguese, explanation: nil)
        #expect(first.text == "Gdé")
        #expect(first.language == .brazilianPortuguese)

        env.vocabulary.deleteNote(second)
        #expect(word.sortedPronunciationNotes.map(\.text) == ["Gdé"])
    }
}

@MainActor
@Suite("Recording persistence")
struct RecordingPersistenceTests {
    func savedTake(_ env: TestEnvironment) throws -> RecordingResult {
        let location = env.audioStore.newRecordingLocation()
        try Data([1, 2, 3]).write(to: location.url)
        return RecordingResult(id: UUID(), relativePath: location.relativePath, duration: 1.8,
                               createdAt: env.now, kind: .personal, source: .recorded)
    }

    @Test func multipleRecordingsAreAssociatedWithTheirWord() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        let first = env.vocabulary.addRecording(try savedTake(env), to: word)
        env.vocabulary.addRecording(try savedTake(env), to: word)
        #expect(word.sortedRecordings.count == 2)
        #expect(first.kind == .personal)
        #expect(first.title == "Take 1")
        #expect(word.sortedRecordings.map(\.title) == ["Take 1", "Take 2"])
        #expect(env.vocabulary.isAvailable(first))
    }

    @Test func renamingAndAnnotating() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        let recording = env.vocabulary.addRecording(try savedTake(env), to: word)
        env.vocabulary.rename(recording, title: "Slow", annotation: "Stress on the е")
        #expect(recording.title == "Slow")
        #expect(recording.annotation == "Stress on the е")
    }

    @Test func deletingARecordingRemovesItsFile() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        let recording = env.vocabulary.addRecording(try savedTake(env), to: word)
        let path = recording.relativePath
        env.vocabulary.deleteRecording(recording)
        #expect(!env.audioStore.fileExists(path))
        #expect(word.sortedRecordings.isEmpty)
    }

    @Test func deletingAWordRemovesItsNotesRecordingsAndFiles() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        try env.vocabulary.addNote(try PronunciationNoteDraft(text: "Kadé", language: .french), to: word)
        let path = env.vocabulary.addRecording(try savedTake(env), to: word).relativePath
        env.vocabulary.delete(word)
        try env.context.save()
        #expect(try env.context.fetchCount(FetchDescriptor<PronunciationNote>()) == 0)
        #expect(try env.context.fetchCount(FetchDescriptor<AudioRecording>()) == 0)
        #expect(!env.audioStore.fileExists(path))
    }

    @Test func missingAudioFileIsReported() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        let recording = env.vocabulary.addRecording(try savedTake(env), to: word)
        try FileManager.default.removeItem(at: env.audioStore.url(for: recording.relativePath))
        #expect(!env.vocabulary.isAvailable(recording))
    }
}

@MainActor
@Suite("Word photos")
struct WordPhotoTests {
    @Test func attachingReplacingAndRemovingAPhoto() throws {
        var env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "кот", meaning: "cat", topic: .animals)
        #expect(word.photoData == nil)

        env.now += 60
        env.vocabulary.setPhoto(Data([1, 2, 3]), for: word)
        #expect(word.photoData == Data([1, 2, 3]))
        #expect(word.dateUpdated == env.now)

        env.vocabulary.setPhoto(Data([4, 5]), for: word)
        #expect(word.photoData == Data([4, 5]))

        env.vocabulary.setPhoto(nil, for: word)
        #expect(word.photoData == nil)
    }

    @Test func compressedPhotoIsSmallAndBounded() throws {
        let big = PhotoEncoder.render(color: .orange, size: CGSize(width: 4032, height: 3024))
        let jpeg = try #require(PhotoEncoder.compressedJPEG(from: big))
        let decoded = try #require(UIImage(data: jpeg))
        #expect(max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale) <= 512)
        #expect(jpeg.count < 100_000)
    }

    @Test func photoSurvivesReopeningTheStore() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Photo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let storeURL = folder.appendingPathComponent("MyRussian.store")
        do {
            let env = try TestEnvironment(inMemory: false, storeURL: storeURL, audioDirectory: folder.appendingPathComponent("A"))
            let word = try env.vocabulary.addWord(russian: "кот", meaning: "cat")
            env.vocabulary.setPhoto(Data(repeating: 9, count: 2048), for: word)
            try env.context.save()
        }
        let reopened = try TestEnvironment(inMemory: false, storeURL: storeURL, audioDirectory: folder.appendingPathComponent("A"))
        #expect(reopened.vocabulary.allWords().first?.photoData == Data(repeating: 9, count: 2048))
    }
}

@MainActor
@Suite("Letter recordings")
struct LetterRecordingTests {
    func take(_ env: TestEnvironment) throws -> RecordingResult {
        let location = env.audioStore.newRecordingLocation()
        try Data([1, 2, 3]).write(to: location.url)
        return RecordingResult(id: UUID(), relativePath: location.relativePath, duration: 0.9,
                               createdAt: env.now, kind: .personal, source: .recorded)
    }

    @Test func savingALetterRecordingMarksItRecorded() throws {
        let env = try TestEnvironment()
        let store = LetterRecordingStore(context: env.context, audioStore: env.audioStore)
        store.save(try take(env), letterID: "ж", kind: .letterName)
        #expect(store.library().hasRecordedName("ж"))
        #expect(store.library().playback(for: "ж", .letterName) == .personal)
        #expect(store.library().playback(for: "ж", .exampleWord) == .synthesized)
    }

    @Test func recordingAgainReplacesTheOldTakeAndDeletesItsFile() throws {
        let env = try TestEnvironment()
        let store = LetterRecordingStore(context: env.context, audioStore: env.audioStore)
        let first = try take(env)
        store.save(first, letterID: "ж", kind: .letterName)
        store.save(try take(env), letterID: "ж", kind: .letterName)
        #expect(try env.context.fetchCount(FetchDescriptor<LetterRecording>()) == 1)
        #expect(!env.audioStore.fileExists(first.relativePath))
    }

    @Test func deletingRemovesTheRecordingAndFile() throws {
        let env = try TestEnvironment()
        let store = LetterRecordingStore(context: env.context, audioStore: env.audioStore)
        let result = try take(env)
        store.save(result, letterID: "к", kind: .exampleWord)
        store.delete(letterID: "к", kind: .exampleWord)
        #expect(!store.library().has("к", .exampleWord))
        #expect(!env.audioStore.fileExists(result.relativePath))
    }

    @Test func recordingsWithMissingFilesAreTreatedAsAbsent() throws {
        let env = try TestEnvironment()
        let store = LetterRecordingStore(context: env.context, audioStore: env.audioStore)
        let result = try take(env)
        store.save(result, letterID: "а", kind: .letterName)
        try FileManager.default.removeItem(at: env.audioStore.url(for: result.relativePath))
        #expect(!store.library().hasRecordedName("а"))
    }
}

@MainActor
@Suite("Widget snapshot writer")
struct WidgetSnapshotWriterTests {
    @Test func writesWordsWithTheirPronunciationsForTheWidget() throws {
        let env = try TestEnvironment()
        let word = try env.vocabulary.addWord(russian: "где", meaning: "where")
        env.vocabulary.addNote(try PronunciationNoteDraft(text: "Kadé", language: .french), to: word)
        try env.vocabulary.addWord(russian: "кот", meaning: "cat")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Widget-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try WidgetSnapshotWriter.write(words: env.vocabulary.allWords(), to: folder)

        let snapshot = try WidgetSnapshot.decode(Data(contentsOf: folder.appendingPathComponent(WidgetSnapshot.fileName)))
        #expect(Set(snapshot.words.map(\.russian)) == ["где", "кот"])
        let где = try #require(snapshot.words.first { $0.russian == "где" })
        #expect(где.id == word.id.uuidString)
        #expect(где.pronunciationLine == "🇫🇷 Kadé")
        #expect(где.confidence == ConfidenceLevel.learning.rawValue, "Confidence drives the random word's weighting")
    }
}

@MainActor
@Suite("Persistence across launches")
struct RelaunchPersistenceTests {
    @Test func wordsNotesAndRecordingsSurviveReopeningTheStore() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Relaunch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let storeURL = folder.appendingPathComponent("MyRussian.store")
        let audioDirectory = folder.appendingPathComponent("Recordings")
        var path = ""

        do {
            let env = try TestEnvironment(inMemory: false, storeURL: storeURL, audioDirectory: audioDirectory)
            let word = try env.vocabulary.addWord(russian: "женщины", meaning: "women")
            try env.vocabulary.addNote(try PronunciationNoteDraft(text: "Gente-chima", language: .brazilianPortuguese), to: word)
            let location = env.audioStore.newRecordingLocation()
            try Data([9]).write(to: location.url)
            path = env.vocabulary.addRecording(
                RecordingResult(id: UUID(), relativePath: location.relativePath, duration: 2, createdAt: env.now,
                                kind: .personal, source: .recorded), to: word).relativePath
            try env.studyLog.log(StudySessionDraft(start: env.now - 3600, duration: 1200, category: .speaking))
            try env.context.save()
        }

        let reopened = try TestEnvironment(inMemory: false, storeURL: storeURL, audioDirectory: audioDirectory)
        let word = try #require(reopened.vocabulary.allWords().first)
        #expect(word.russian == "женщины")
        #expect(word.sortedPronunciationNotes.first?.text == "Gente-chima")
        #expect(word.sortedPronunciationNotes.first?.language == .brazilianPortuguese)
        #expect(word.sortedRecordings.first?.relativePath == path)
        #expect(reopened.audioStore.fileExists(path))
        #expect(reopened.studyLog.allSessions().first?.category == .speaking)
    }
}
