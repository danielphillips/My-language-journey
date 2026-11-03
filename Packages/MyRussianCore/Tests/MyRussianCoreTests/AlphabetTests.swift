import Testing
@testable import MyRussianCore

@Suite("Russian alphabet")
struct RussianAlphabetTests {
    let letters = RussianAlphabet.letters

    @Test func thirtyThreeLettersInAlphabeticalOrder() {
        #expect(letters.count == 33)
        #expect(letters.map(\.uppercase).joined() == "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
        #expect(letters.map(\.lowercase).joined() == "абвгдеёжзийклмнопрстуфхцчшщъыьэюя")
    }

    @Test func tenVowelsTwentyOneConsonantsAndTwoSigns() {
        #expect(letters.filter { $0.kind == .vowel }.map(\.lowercase).joined() == "аеёиоуыэюя")
        #expect(letters.filter { $0.kind == .consonant }.count == 21)
        #expect(letters.filter { $0.kind == .sign }.map(\.lowercase) == ["ъ", "ь"])
    }

    @Test func spokenNamesAreTheTraditionalLetterNames() {
        let names = Dictionary(uniqueKeysWithValues: letters.map { ($0.lowercase, $0.spokenName) })
        #expect(names["б"] == "бэ")
        #expect(names["л"] == "эль")
        #expect(names["й"] == "и краткое")
        #expect(names["ъ"] == "твёрдый знак")
        #expect(names["ь"] == "мягкий знак")
        #expect(names["а"] == "а")
    }

    @Test func everyLetterHasASoundHintAndAnExampleContainingIt() {
        for letter in letters {
            #expect(!letter.soundHint.isEmpty, "\(letter.uppercase) needs a sound hint")
            #expect(!letter.exampleMeaning.isEmpty)
            #expect(letter.exampleWord.lowercased().contains(letter.lowercase),
                    "\(letter.exampleWord) should contain \(letter.lowercase)")
        }
    }

    @Test func identifiersAreUniqueAndStable() {
        #expect(Set(letters.map(\.id)).count == 33)
        #expect(letters.first?.id == "а")
    }
}
