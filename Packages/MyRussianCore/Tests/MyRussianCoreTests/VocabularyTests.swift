import Foundation
import Testing
@testable import MyRussianCore

private func word(
    _ russian: String, _ meaning: String, _ confidence: ConfidenceLevel = .learning,
    added: Date = date(2026, 11, 1), updated: Date? = nil, pronunciations: [String] = []
) -> VocabularySnapshot {
    VocabularySnapshot(id: UUID(), russian: russian, meaning: meaning, confidence: confidence,
                       dateAdded: added, dateUpdated: updated ?? added, pronunciationTexts: pronunciations)
}

@Suite("Confidence levels")
struct ConfidenceLevelTests {
    @Test func fourOrderedLevels() {
        #expect(ConfidenceLevel.allCases.map(\.title) == ["Learning", "Recognise", "Comfortable", "Confident"])
        #expect(ConfidenceLevel.learning < ConfidenceLevel.confident)
    }

    @Test func activeVocabularyIsComfortablePlusConfident() {
        #expect(ConfidenceLevel.allCases.filter(\.isActive) == [.comfortable, .confident])
    }

    @Test func everyLevelExplainsItself() {
        #expect(ConfidenceLevel.recognise.explanation == "I understand it when I see or hear it.")
    }
}

@Suite("Russian text handling")
struct RussianTextTests {
    @Test func storagePreservesCyrillicExactlyApartFromSurroundingWhitespace() {
        #expect(VocabularyText.cleanedForStorage("  Здра́вствуйте!  \n") == "Здра́вствуйте!")
        #expect(VocabularyText.cleanedForStorage("ёлка") == "ёлка")
        #expect(VocabularyText.cleanedForStorage("Добрый   день") == "Добрый   день")
    }

    @Test func matchingIgnoresCaseStressMarksYoAndSpacing() {
        #expect(VocabularyText.matchKey("  Здра́вствуйте ") == VocabularyText.matchKey("здравствуйте"))
        #expect(VocabularyText.matchKey("Ёлка") == VocabularyText.matchKey("елка"))
        #expect(VocabularyText.matchKey("Добрый   день") == VocabularyText.matchKey("добрый день"))
    }

    @Test func matchingKeepsLettersThatAreNotStressMarks() {
        // й is и + breve: it is a distinct letter and must not collapse to и.
        #expect(VocabularyText.matchKey("мой") != VocabularyText.matchKey("мои"))
    }
}

@Suite("Duplicate detection")
struct DuplicateDetectionTests {
    let existing = [word("где", "where"), word("мир", "peace")]

    @Test func newWordIsUnique() {
        #expect(VocabularyDuplicateDetector.check(russian: "женщины", meaning: "women", among: existing) == .unique)
    }

    @Test func sameWordAndMeaningIsADuplicate() {
        let result = VocabularyDuplicateDetector.check(russian: "Где ", meaning: " Where", among: existing)
        #expect(result == .duplicate(existing[0].id))
    }

    @Test func sameWordWithADifferentMeaningIsAllowedButFlagged() {
        // мир means both "peace" and "world".
        let result = VocabularyDuplicateDetector.check(russian: "мир", meaning: "world", among: existing)
        #expect(result == .sameWordDifferentMeaning([existing[1].id]))
        #expect(result.blocksSaving == false)
    }

    @Test func editingAnEntryDoesNotConflictWithItself() {
        let result = VocabularyDuplicateDetector.check(russian: "где", meaning: "where", among: existing, excluding: existing[0].id)
        #expect(result == .unique)
    }
}

@Suite("Vocabulary query")
struct VocabularyQueryTests {
    let words = [
        word("где", "where", .confident, added: date(2026, 10, 1), updated: date(2026, 11, 3), pronunciations: ["Kadé"]),
        word("женщины", "women", .recognise, added: date(2026, 10, 5), pronunciations: ["Gente-chima"]),
        word("ёж", "hedgehog", .learning, added: date(2026, 10, 10)),
        word("арбуз", "watermelon", .comfortable, added: date(2026, 10, 3))
    ]

    @Test func emptyQueryReturnsEverythingMostRecentFirst() {
        #expect(VocabularyQuery().apply(to: words).map(\.russian) == ["ёж", "женщины", "арбуз", "где"])
    }

    @Test func searchMatchesRussianIgnoringCaseAndYo() {
        #expect(VocabularyQuery(searchText: "ЕЖ").apply(to: words).map(\.russian) == ["ёж"])
    }

    @Test func searchMatchesMeaning() {
        #expect(VocabularyQuery(searchText: "wom").apply(to: words).map(\.russian) == ["женщины"])
    }

    @Test func searchMatchesPersonalPronunciationNotes() {
        #expect(VocabularyQuery(searchText: "kade").apply(to: words).map(\.russian) == ["где"])
    }

    @Test func filterByConfidence() {
        let query = VocabularyQuery(confidences: [.comfortable, .confident])
        #expect(Set(query.apply(to: words).map(\.russian)) == ["где", "арбуз"])
    }

    @Test func alphabeticalSortFollowsTheRussianAlphabet() {
        // Ё sorts with Е, before Ж.
        let sorted = VocabularyQuery(sort: .alphabetical).apply(to: words).map(\.russian)
        #expect(sorted == ["арбуз", "где", "ёж", "женщины"])
    }

    @Test func recentlyUpdatedSort() {
        #expect(VocabularyQuery(sort: .recentlyUpdated).apply(to: words).first?.russian == "где")
    }

    @Test func confidenceSortPutsWordsThatNeedWorkFirst() {
        let sorted = VocabularyQuery(sort: .confidence).apply(to: words).map(\.confidence)
        #expect(sorted == [.learning, .recognise, .comfortable, .confident])
    }
}

@Suite("Vocabulary statistics")
struct VocabularyStatisticsTests {
    @Test func countsAreMutuallyExclusiveAndSumToTheTotal() {
        let stats = VocabularyStatistics(items: [
            word("а", "and", .confident), word("да", "yes", .confident),
            word("нет", "no", .comfortable), word("кто", "who", .recognise), word("что", "what", .learning)
        ])
        #expect(stats.total == 5)
        #expect(stats.count(of: .learning) == 1)
        #expect(stats.count(of: .recognise) == 1)
        #expect(stats.count(of: .comfortable) == 1)
        #expect(stats.count(of: .confident) == 2)
        #expect(ConfidenceLevel.allCases.map(stats.count(of:)).reduce(0, +) == stats.total)
        #expect(stats.activeCount == 3)
    }

    @Test func emptyCollection() {
        let stats = VocabularyStatistics(items: [VocabularySnapshot]())
        #expect(stats.total == 0)
        #expect(stats.recentlyAdded(limit: 5).isEmpty)
    }

    @Test func recentlyAddedNewestFirst() {
        let stats = VocabularyStatistics(items: [
            word("один", "one", added: date(2026, 10, 1)),
            word("два", "two", added: date(2026, 10, 3)),
            word("три", "three", added: date(2026, 10, 2))
        ])
        #expect(stats.recentlyAdded(limit: 2).map(\.russian) == ["два", "три"])
    }

    @Test func cumulativeGrowthByWeek() {
        let stats = VocabularyStatistics(items: [
            word("один", "one", added: date(2026, 10, 20)),
            word("два", "two", added: date(2026, 10, 21)),
            word("три", "three", added: date(2026, 11, 3))
        ])
        let growth = stats.weeklyGrowth(endingWith: date(2026, 11, 4), weeks: 3, calendar: testCalendar)
        #expect(growth.map(\.weekStart) == [date(2026, 10, 19), date(2026, 10, 26), date(2026, 11, 2)])
        #expect(growth.map(\.total) == [2, 2, 3])
    }

    @Test func a1LexicalMinimumIsAReferenceFigureOnly() {
        #expect(VocabularyStatistics.a1LexicalMinimumReference == 780)
    }
}
