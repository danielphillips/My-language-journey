import Foundation
import Testing
@testable import MyRussianCore

private func widgetWord(_ id: String, _ russian: String, _ meaning: String, added: Date,
                        notes: [WidgetPronunciation] = []) -> WidgetWord {
    WidgetWord(id: id, russian: russian, meaning: meaning, pronunciations: notes, dateAdded: added)
}

@Suite("Widget snapshot")
struct WidgetSnapshotTests {
    let snapshot = WidgetSnapshot(words: [
        widgetWord("1", "где", "where", added: date(2026, 10, 1), notes: [WidgetPronunciation(text: "Kadé", flag: "🇫🇷")]),
        widgetWord("2", "кот", "cat", added: date(2026, 11, 3)),
        widgetWord("3", "женщины", "women", added: date(2026, 10, 20),
                   notes: [WidgetPronunciation(text: "Gente-chima", flag: "🇧🇷"), WidgetPronunciation(text: "Jène", flag: "🇫🇷")])
    ])

    @Test func showsTheChosenWord() {
        #expect(snapshot.resolve(selectedID: "1")?.russian == "где")
    }

    @Test func withoutAChoiceShowsTheMostRecentlyAddedWord() {
        #expect(snapshot.resolve(selectedID: nil)?.russian == "кот")
    }

    @Test func aDeletedChoiceFallsBackToTheMostRecentWord() {
        #expect(snapshot.resolve(selectedID: "gone")?.russian == "кот")
    }

    @Test func emptyVocabularyShowsNothing() {
        #expect(WidgetSnapshot(words: []).resolve(selectedID: nil) == nil)
    }

    @Test func pronunciationLineIsTheFirstNoteWithItsFlagVerbatim() {
        #expect(snapshot.resolve(selectedID: "3")?.pronunciationLine == "🇧🇷 Gente-chima")
        #expect(snapshot.resolve(selectedID: "2")?.pronunciationLine == nil)
    }

    @Test func inlineTextUsesThePronunciationOrFallsBackToTheMeaning() {
        #expect(snapshot.resolve(selectedID: "1")?.inlineText == "где · Kadé")
        #expect(snapshot.resolve(selectedID: "2")?.inlineText == "кот · cat")
    }

    @Test func roundTripsThroughJSONKeepingSpellingsExactly() throws {
        let decomposed = "Kade\u{0301}"
        let original = WidgetSnapshot(words: [widgetWord("9", "где", "where", added: date(2026, 1, 1),
                                                         notes: [WidgetPronunciation(text: decomposed, flag: "🇫🇷")])])
        let decoded = try WidgetSnapshot.decode(original.encoded())
        #expect(decoded == original)
        #expect(Array(decoded.words[0].pronunciations[0].text.unicodeScalars) == Array(decomposed.unicodeScalars))
    }

    @Test func pickerListsMostRecentFirstAndSearchesEverything() {
        #expect(snapshot.suggested().map(\.russian) == ["кот", "женщины", "где"])
        #expect(snapshot.search("kade").map(\.russian) == ["где"])
        #expect(snapshot.search("WOM").map(\.russian) == ["женщины"])
        #expect(snapshot.search("кот").map(\.russian) == ["кот"])
    }

    @Test func builtFromVocabularyItems() {
        let item = VocabularySnapshot(russian: "где", meaning: "where", confidence: .confident,
                                      dateAdded: date(2026, 10, 1), dateUpdated: date(2026, 10, 1))
        let word = WidgetWord(item: item, pronunciations: [WidgetPronunciation(text: "Kadé", flag: "🇫🇷")])
        #expect(word.id == item.id.uuidString)
        #expect(word.inlineText == "где · Kadé")
    }
}
