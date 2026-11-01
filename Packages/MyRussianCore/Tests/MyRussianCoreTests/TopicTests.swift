import Foundation
import Testing
@testable import MyRussianCore

private func word(_ russian: String, _ topic: VocabularyTopic?, _ confidence: ConfidenceLevel = .learning,
                  meaning: String = "x") -> VocabularySnapshot {
    VocabularySnapshot(russian: russian, meaning: meaning, confidence: confidence,
                       dateAdded: date(2026, 11, 1), dateUpdated: date(2026, 11, 1), topic: topic)
}

@Suite("Vocabulary topics")
struct VocabularyTopicTests {
    @Test func everydayA1TopicsInDisplayOrder() {
        #expect(VocabularyTopic.allCases.map(\.title) == [
            "Greetings & Courtesy", "Questions & Essentials", "People & Family", "Numbers", "Time & Dates",
            "Food & Drink", "Home", "City & Places", "Travel & Transport", "Shopping & Money", "Work & Study",
            "Body & Health", "Nature & Weather", "Animals", "Hobbies & Leisure", "Colours & Describing", "Other"
        ])
    }

    @Test func rawValuesAreStableAndUniqueForPersistence() {
        let raw = VocabularyTopic.allCases.map(\.rawValue)
        #expect(Set(raw).count == raw.count)
        #expect(VocabularyTopic(rawValue: "food") == .food)
        #expect(VocabularyTopic(rawValue: "animals") == .animals)
    }

    @Test func everyTopicHasASymbol() {
        #expect(VocabularyTopic.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }

    @Test func wordsWithoutATopicAreAllowed() {
        #expect(word("где", nil).topic == nil)
    }
}

@Suite("Topic breakdown")
struct TopicBreakdownTests {
    @Test func topicsSortedByWordCountWithConfidenceSplit() {
        let words = [
            word("хлеб", .food, .confident), word("вода", .food, .learning), word("чай", .food, .confident),
            word("кот", .animals, .recognise),
            word("где", nil, .confident)
        ]
        let breakdown = VocabularyStatistics(items: words).topicBreakdown
        #expect(breakdown.map(\.topic) == [.food, .animals, nil])
        #expect(breakdown.map(\.total) == [3, 1, 1])
        let food = breakdown[0]
        #expect(food.counts.map(\.level) == [.learning, .recognise, .comfortable, .confident])
        #expect(food.counts.map(\.count) == [1, 0, 0, 2])
    }

    @Test func uncategorisedWordsComeLastEvenWhenMostNumerous() {
        let words = [word("а", nil), word("б", nil), word("в", nil), word("кот", .animals)]
        #expect(VocabularyStatistics(items: words).topicBreakdown.map(\.topic) == [.animals, nil])
    }

    @Test func tiesFollowTopicOrder() {
        let words = [word("кот", .animals), word("хлеб", .food)]
        #expect(VocabularyStatistics(items: words).topicBreakdown.map(\.topic) == [.food, .animals])
    }

    @Test func emptyTopicsAreOmitted() {
        #expect(VocabularyStatistics(items: [VocabularySnapshot]()).topicBreakdown.isEmpty)
    }
}

@Suite("Topic filter")
struct TopicFilterTests {
    let words = [word("хлеб", .food), word("кот", .animals), word("где", nil)]

    @Test func filteringByTopic() {
        var query = VocabularyQuery()
        query.topic = .food
        #expect(query.apply(to: words).map(\.russian) == ["хлеб"])
    }

    @Test func noTopicFilterShowsEverything() {
        #expect(VocabularyQuery().apply(to: words).count == 3)
    }

    @Test func topicAndConfidenceFiltersCombine() {
        let mixed = [word("хлеб", .food, .confident), word("вода", .food, .learning), word("кот", .animals, .confident)]
        var query = VocabularyQuery()
        query.topic = .food
        query.confidenceFilter = .confident
        #expect(query.apply(to: mixed).map(\.russian) == ["хлеб"])
    }
}
