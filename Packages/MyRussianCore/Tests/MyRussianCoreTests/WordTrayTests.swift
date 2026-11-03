import Testing
@testable import MyRussianCore

private func letter(_ lower: String) -> RussianLetter {
    RussianAlphabet.letters.first { $0.lowercase == lower }!
}

@Suite("Word tray")
struct WordTrayTests {
    @Test func lettersAreAddedInOrderToSpellAWord() {
        var tray = WordTray()
        #expect(tray.isEmpty)
        for l in ["к", "о", "т"] { tray.append(letter(l)) }
        #expect(tray.text == "кот")
        #expect(tray.items.count == 3)
    }

    @Test func repeatedLettersAreSeparateItems() {
        var tray = WordTray()
        for l in ["м", "а", "м", "а"] { tray.append(letter(l)) }
        #expect(tray.text == "мама")
        #expect(Set(tray.items.map(\.id)).count == 4)
    }

    @Test func backspaceRemovesTheLastLetter() {
        var tray = WordTray()
        for l in ["д", "о", "м", "а"] { tray.append(letter(l)) }
        tray.removeLast()
        #expect(tray.text == "дом")
        tray.removeLast(); tray.removeLast(); tray.removeLast(); tray.removeLast()
        #expect(tray.isEmpty)
    }

    @Test func anyLetterCanBeRemovedByTappingIt() {
        var tray = WordTray()
        for l in ["к", "и", "о", "т"] { tray.append(letter(l)) }
        tray.remove(tray.items[1].id)
        #expect(tray.text == "кот")
    }

    @Test func clearEmptiesTheTray() {
        var tray = WordTray()
        tray.append(letter("я"))
        tray.clear()
        #expect(tray.isEmpty)
        #expect(tray.text.isEmpty)
    }

    @Test func trayHasAMaximumLength() {
        var tray = WordTray()
        for _ in 0..<(WordTray.maximumLength + 5) { tray.append(letter("а")) }
        #expect(tray.items.count == WordTray.maximumLength)
    }
}

@Suite("Word checker")
struct WordCheckerTests {
    let vocabulary = [KnownWord(russian: "кот", meaning: "cat"), KnownWord(russian: "Здра́вствуйте", meaning: "hello")]
    let noDictionary: (String) -> Bool = { _ in false }

    @Test func emptyTrayHasNoVerdict() {
        #expect(WordChecker.verdict(for: "", vocabulary: vocabulary, isDictionaryWord: noDictionary) == .empty)
    }

    @Test func wordsInYourVocabularyAreRecognisedWithYourMeaning() {
        let verdict = WordChecker.verdict(for: "кот", vocabulary: vocabulary, isDictionaryWord: noDictionary)
        #expect(verdict == .inYourVocabulary(meaning: "cat"))
        #expect(verdict.isCorrect)
    }

    @Test func vocabularyMatchingIgnoresStressMarksAndCase() {
        #expect(WordChecker.verdict(for: "здравствуйте", vocabulary: vocabulary, isDictionaryWord: noDictionary)
                == .inYourVocabulary(meaning: "hello"))
    }

    @Test func alphabetExampleWordsAreRecognisedWithTheirMeaning() {
        #expect(WordChecker.verdict(for: "жук", vocabulary: [], isDictionaryWord: noDictionary)
                == .exampleWord(meaning: "beetle"))
    }

    @Test func otherRealWordsAreRecognisedByTheDictionary() {
        let verdict = WordChecker.verdict(for: "собака", vocabulary: [], isDictionaryWord: { $0 == "собака" })
        #expect(verdict == .dictionaryWord)
        #expect(verdict.isCorrect)
    }

    @Test func yourVocabularyTakesPriorityOverTheDictionary() {
        #expect(WordChecker.verdict(for: "кот", vocabulary: vocabulary, isDictionaryWord: { _ in true })
                == .inYourVocabulary(meaning: "cat"))
    }

    @Test func unknownLetterSequencesAreNotCorrect() {
        let verdict = WordChecker.verdict(for: "ктщ", vocabulary: vocabulary, isDictionaryWord: noDictionary)
        #expect(verdict == .unrecognised)
        #expect(!verdict.isCorrect)
    }

    @Test func signsAloneAreNeverWords() {
        #expect(WordChecker.verdict(for: "ъ", vocabulary: [], isDictionaryWord: { _ in true }) == .unrecognised)
    }
}
