import Foundation

/// Letters collected from the alphabet grid to spell a word.
public struct WordTray: Equatable, Sendable {
    public struct Item: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let letter: RussianLetter
    }

    public static let maximumLength = 24

    public private(set) var items: [Item] = []

    public init() {}

    public var isEmpty: Bool { items.isEmpty }
    public var text: String { items.map(\.letter.lowercase).joined() }

    public mutating func append(_ letter: RussianLetter) {
        guard items.count < Self.maximumLength else { return }
        items.append(Item(id: UUID(), letter: letter))
    }

    public mutating func removeLast() {
        _ = items.popLast()
    }

    public mutating func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    public mutating func clear() {
        items.removeAll()
    }
}

public struct KnownWord: Equatable, Sendable {
    public let russian: String
    public let meaning: String

    public init(russian: String, meaning: String) {
        self.russian = russian
        self.meaning = meaning
    }
}

public enum WordVerdict: Equatable, Sendable {
    case empty
    case inYourVocabulary(meaning: String)
    case exampleWord(meaning: String)
    case dictionaryWord
    case unrecognised

    public var isCorrect: Bool {
        switch self {
        case .inYourVocabulary, .exampleWord, .dictionaryWord: true
        case .empty, .unrecognised: false
        }
    }
}

public enum WordChecker {
    /// Checks your vocabulary first, then the alphabet's example words, then a dictionary lookup.
    public static func verdict(for text: String, vocabulary: [KnownWord],
                               isDictionaryWord: (String) -> Bool) -> WordVerdict {
        let key = VocabularyText.matchKey(text)
        guard !key.isEmpty else { return .empty }
        guard key.contains(where: { !"ъь".contains($0) }) else { return .unrecognised }

        if let mine = vocabulary.first(where: { VocabularyText.matchKey($0.russian) == key }) {
            return .inYourVocabulary(meaning: mine.meaning)
        }
        if let example = RussianAlphabet.letters.first(where: { VocabularyText.matchKey($0.exampleWord) == key }) {
            return .exampleWord(meaning: example.exampleMeaning)
        }
        return isDictionaryWord(text) ? .dictionaryWord : .unrecognised
    }
}
