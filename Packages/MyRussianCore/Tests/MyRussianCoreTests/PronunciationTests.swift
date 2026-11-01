import Foundation
import Testing
@testable import MyRussianCore

@Suite("Reference languages")
struct ReferenceLanguageTests {
    @Test func initialLanguagesWithFlags() {
        #expect(ReferenceLanguage.allCases == [.french, .brazilianPortuguese, .english])
        #expect(ReferenceLanguage.allCases.map(\.flag) == ["🇫🇷", "🇧🇷", "🇬🇧"])
        #expect(ReferenceLanguage.allCases.map(\.name) == ["French", "Brazilian Portuguese", "English"])
    }

    @Test func rawValuesAreStableForPersistence() {
        #expect(ReferenceLanguage.allCases.map(\.rawValue) == ["fr", "pt-BR", "en"])
    }

    @Test func quickEntrySuggestsTheMostRecentlyUsedLanguage() {
        #expect(ReferenceLanguage.suggested(recentlyUsed: []) == .french)
        #expect(ReferenceLanguage.suggested(recentlyUsed: [.brazilianPortuguese, .french]) == .brazilianPortuguese)
    }
}

@Suite("Pronunciation notes")
struct PronunciationNoteTests {
    @Test func keepsThePersonalSpellingExactlyAsTyped() throws {
        let note = try PronunciationNoteDraft(text: "Gente-chima", language: .brazilianPortuguese)
        #expect(note.text == "Gente-chima")
        #expect(note.language == .brazilianPortuguese)
        #expect(note.flag == "🇧🇷")
    }

    @Test func neverNormalisesUnicodeCaseOrSpacing() throws {
        let decomposed = "Kade\u{0301}" // é typed as e + combining acute
        let note = try PronunciationNoteDraft(text: decomposed, language: .french)
        #expect(Array(note.text.unicodeScalars) == Array(decomposed.unicodeScalars))

        let spaced = try PronunciationNoteDraft(text: " ZHEN-shi-ny  ", language: .english)
        #expect(spaced.text == " ZHEN-shi-ny  ")
    }

    @Test func blankSpellingsAreRejected() {
        #expect(throws: PronunciationNoteError.emptyText) {
            try PronunciationNoteDraft(text: "  \n ", language: .french)
        }
    }

    @Test func explanationIsOptional() throws {
        let note = try PronunciationNoteDraft(text: "Kadé", language: .french, explanation: "   ")
        #expect(note.explanation == nil)
        let explained = try PronunciationNoteDraft(text: "Kadé", language: .french, explanation: "Like « cadet » without the t")
        #expect(explained.explanation == "Like « cadet » without the t")
    }

    @Test func changingLanguageKeepsTheText() throws {
        var note = try PronunciationNoteDraft(text: "Kadé", language: .french)
        note.language = .english
        #expect(note.text == "Kadé")
        #expect(note.flag == "🇬🇧")
    }
}
