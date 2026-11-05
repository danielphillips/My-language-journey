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

    let now = date(2026, 11, 5, 10)

    @Test func showsTheChosenWordWhateverTheTime() {
        #expect(snapshot.word(for: .word(id: "1"), at: now, calendar: testCalendar)?.russian == "где")
        #expect(snapshot.word(for: .word(id: "1"), at: date(2026, 11, 9, 18), calendar: testCalendar)?.russian == "где")
    }

    @Test func randomShowsTheWordForTheCurrentSlot() {
        let slot = WordRotation.slotIndex(for: now, calendar: testCalendar)
        #expect(snapshot.word(for: .random, at: now, calendar: testCalendar) == snapshot.randomWord(forSlot: slot))
    }

    @Test func aDeletedChoiceFallsBackToRandom() {
        #expect(snapshot.word(for: .word(id: "gone"), at: now, calendar: testCalendar)
                == snapshot.word(for: .random, at: now, calendar: testCalendar))
    }

    @Test func emptyVocabularyShowsNothing() {
        #expect(WidgetSnapshot(words: []).word(for: .random, at: now, calendar: testCalendar) == nil)
    }

    @Test func pronunciationLineIsTheFirstNoteWithItsFlagVerbatim() {
        #expect(snapshot.words[2].pronunciationLine == "🇧🇷 Gente-chima")
        #expect(snapshot.words[1].pronunciationLine == nil)
    }

    @Test func inlineTextUsesThePronunciationOrFallsBackToTheMeaning() {
        #expect(snapshot.words[0].inlineText == "где · Kadé")
        #expect(snapshot.words[1].inlineText == "кот · cat")
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

@Suite("Lock-screen pronunciation line")
struct LockScreenPronunciationTests {
    @Test func flagsBecomeShortLanguageLabelsBecauseTheLockScreenTintsEmojiIntoBlocks() {
        #expect(WidgetPronunciation(text: "Kadé", flag: "🇫🇷").languageLabel == "FR")
        #expect(WidgetPronunciation(text: "patria sayou chayâ", flag: "🇧🇷").languageLabel == "PT")
        #expect(WidgetPronunciation(text: "gdyeh", flag: "🇬🇧").languageLabel == "EN")
    }

    @Test func lockScreenLineUsesTheLabelAndKeepsTheSpellingVerbatim() {
        let word = WidgetWord(id: "1", russian: "Потрясающе", meaning: "Stunning",
                              pronunciations: [WidgetPronunciation(text: "patria sayou chayâ", flag: "🇧🇷")],
                              dateAdded: .now)
        #expect(word.lockScreenPronunciationLine == "PT · patria sayou chayâ")
    }

    @Test func unknownFlagsAreLeftOutRatherThanGuessed() {
        let word = WidgetWord(id: "1", russian: "кот", meaning: "cat",
                              pronunciations: [WidgetPronunciation(text: "kot", flag: "🏳️")], dateAdded: .now)
        #expect(word.lockScreenPronunciationLine == "kot")
    }
}


@Suite("Word rotation (twice a day)")
struct WordRotationTests {
    @Test func slotsStartAtFiveAndSeventeen() {
        #expect(WordRotation.slotStart(containing: date(2026, 11, 5, 5), calendar: testCalendar) == date(2026, 11, 5, 5))
        #expect(WordRotation.slotStart(containing: date(2026, 11, 5, 16, 59), calendar: testCalendar) == date(2026, 11, 5, 5))
        #expect(WordRotation.slotStart(containing: date(2026, 11, 5, 17), calendar: testCalendar) == date(2026, 11, 5, 17))
        #expect(WordRotation.slotStart(containing: date(2026, 11, 5, 23, 30), calendar: testCalendar) == date(2026, 11, 5, 17))
    }

    @Test func earlyMorningBelongsToThePreviousEveningsSlot() {
        #expect(WordRotation.slotStart(containing: date(2026, 11, 5, 4, 59), calendar: testCalendar) == date(2026, 11, 4, 17))
        #expect(WordRotation.slotStart(containing: date(2026, 11, 5, 0, 0), calendar: testCalendar) == date(2026, 11, 4, 17))
    }

    @Test func nextSlotStart() {
        #expect(WordRotation.nextSlotStart(after: date(2026, 11, 5, 10), calendar: testCalendar) == date(2026, 11, 5, 17))
        #expect(WordRotation.nextSlotStart(after: date(2026, 11, 5, 20), calendar: testCalendar) == date(2026, 11, 6, 5))
        #expect(WordRotation.nextSlotStart(after: date(2026, 11, 5, 3), calendar: testCalendar) == date(2026, 11, 5, 5))
    }

    @Test func slotIndexesAreConsecutive() {
        let morning = WordRotation.slotIndex(for: date(2026, 11, 5, 6), calendar: testCalendar)
        #expect(WordRotation.slotIndex(for: date(2026, 11, 5, 18), calendar: testCalendar) == morning + 1)
        #expect(WordRotation.slotIndex(for: date(2026, 11, 6, 2), calendar: testCalendar) == morning + 1)
        #expect(WordRotation.slotIndex(for: date(2026, 11, 6, 5), calendar: testCalendar) == morning + 2)
    }

    @Test func clockChangeDaysKeepLocalFiveAndSeventeen() {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        func local(_ d: Int, _ h: Int) -> Date { london.date(from: DateComponents(year: 2026, month: 3, day: d, hour: h))! }
        // Clocks go forward on 29 March 2026.
        #expect(WordRotation.slotStart(containing: local(29, 6), calendar: london) == local(29, 5))
        #expect(WordRotation.nextSlotStart(after: local(29, 6), calendar: london) == local(29, 17))
        #expect(WordRotation.slotIndex(for: local(29, 6), calendar: london)
                == WordRotation.slotIndex(for: local(28, 18), calendar: london) + 1)
    }
}

@Suite("Random word")
struct RandomWordTests {
    // Two learning words (weight 3 each) and three confident ones (weight 1): 9 places per cycle.
    let snapshot = WidgetSnapshot(words: [
        WidgetWord(id: "a", russian: "кот", meaning: "cat", pronunciations: [], dateAdded: date(2026, 1, 1), confidence: 1),
        WidgetWord(id: "b", russian: "дом", meaning: "house", pronunciations: [], dateAdded: date(2026, 1, 2), confidence: 2),
        WidgetWord(id: "c", russian: "где", meaning: "where", pronunciations: [], dateAdded: date(2026, 1, 3), confidence: 4),
        WidgetWord(id: "d", russian: "да", meaning: "yes", pronunciations: [], dateAdded: date(2026, 1, 4), confidence: 3),
        WidgetWord(id: "e", russian: "нет", meaning: "no", pronunciations: [], dateAdded: date(2026, 1, 5), confidence: 4)
    ])

    func pick(_ slot: Int) -> String? { snapshot.randomWord(forSlot: slot)?.id }

    @Test func theSameSlotAlwaysGivesTheSameWord() throws {
        let reloaded = try WidgetSnapshot.decode(snapshot.encoded())
        for slot in [-3, 0, 7, 123] {
            #expect(pick(slot) == pick(slot))
            #expect(reloaded.randomWord(forSlot: slot)?.id == pick(slot))
        }
    }

    @Test func neverTheSameWordTwiceInARow() {
        for slot in 0..<200 {
            #expect(pick(slot) != pick(slot + 1), "slots \(slot) and \(slot + 1)")
        }
    }

    @Test func everyWordComesUpWithinACycle() {
        #expect(Set((0..<9).compactMap(pick)) == ["a", "b", "c", "d", "e"])
    }

    @Test func wordsYouAreStillLearningComeUpThreeTimesAsOften() {
        let picks = (0..<90).compactMap(pick)
        #expect(picks.filter { $0 == "a" }.count == 30)
        #expect(picks.filter { $0 == "b" }.count == 30)
        #expect(picks.filter { $0 == "c" }.count == 10)
        #expect(picks.filter { $0 == "e" }.count == 10)
    }

    @Test func aSingleWordIsAlwaysShown() {
        let one = WidgetSnapshot(words: [snapshot.words[0]])
        #expect((0..<10).allSatisfy { one.randomWord(forSlot: $0)?.id == "a" })
    }

    @Test func twoWordsAlternate() {
        let two = WidgetSnapshot(words: [snapshot.words[2], snapshot.words[4]])
        for slot in 0..<20 {
            #expect(two.randomWord(forSlot: slot)?.id != two.randomWord(forSlot: slot + 1)?.id)
        }
    }

    @Test func snapshotsWrittenBeforeConfidenceExistedStillLoad() throws {
        let old = #"{"version":1,"words":[{"id":"x","russian":"кот","meaning":"cat","pronunciations":[],"dateAdded":"2026-11-01T00:00:00Z"}]}"#
        let decoded = try WidgetSnapshot.decode(Data(old.utf8))
        #expect(decoded.words.first?.confidence == nil)
        #expect(decoded.randomWord(forSlot: 4)?.id == "x")
    }
}
