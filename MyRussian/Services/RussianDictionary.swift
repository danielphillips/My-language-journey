import UIKit

/// On-device Russian word check using the system spell-checking dictionary.
@MainActor
enum RussianDictionary {
    private static let language: String? = UITextChecker.availableLanguages.first { $0.hasPrefix("ru") }
    private static let checker = UITextChecker()

    /// `false` when no Russian dictionary is installed, so a word is never wrongly marked correct.
    static func contains(_ word: String) -> Bool {
        guard let language, !word.isEmpty else { return false }
        let range = NSRange(word.startIndex..., in: word)
        let misspelled = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: language)
        return misspelled.location == NSNotFound
    }
}
