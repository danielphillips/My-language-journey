import Foundation

/// A personal phonetic spelling as the widget shows it (verbatim text plus its language flag).
public struct WidgetPronunciation: Codable, Hashable, Sendable {
    public let text: String
    public let flag: String

    public init(text: String, flag: String) {
        self.text = text
        self.flag = flag
    }

    /// "FR", "PT", "EN". The lock screen renders emoji as solid tinted blocks, so it shows this instead of the flag.
    public var languageLabel: String? {
        switch ReferenceLanguage.allCases.first(where: { $0.flag == flag }) {
        case .french: "FR"
        case .brazilianPortuguese: "PT"
        case .english: "EN"
        case nil: nil
        }
    }
}

/// One vocabulary word, as shared with the widget extension.
public struct WidgetWord: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let russian: String
    public let meaning: String
    public let pronunciations: [WidgetPronunciation]
    public let dateAdded: Date

    public init(id: String, russian: String, meaning: String, pronunciations: [WidgetPronunciation], dateAdded: Date) {
        self.id = id
        self.russian = russian
        self.meaning = meaning
        self.pronunciations = pronunciations
        self.dateAdded = dateAdded
    }

    public init<Item: VocabularyItem>(item: Item, pronunciations: [WidgetPronunciation]) where Item.ID == UUID {
        self.init(id: item.id.uuidString, russian: item.russian, meaning: item.meaning,
                  pronunciations: pronunciations, dateAdded: item.dateAdded)
    }

    /// "🇫🇷 Kadé": the first personal pronunciation, verbatim.
    public var pronunciationLine: String? {
        pronunciations.first.map { "\($0.flag) \($0.text)" }
    }

    /// "PT · patria sayou chayâ": the first pronunciation with a text label instead of the flag.
    public var lockScreenPronunciationLine: String? {
        pronunciations.first.map { note in
            note.languageLabel.map { "\($0) · \(note.text)" } ?? note.text
        }
    }

    /// Single-line lock-screen text: "где · Kadé", or "кот · cat" without a pronunciation.
    public var inlineText: String {
        "\(russian) · \(pronunciations.first?.text ?? meaning)"
    }
}

/// The small, read-only copy of your vocabulary the app writes for the widget.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let fileName = "widget-vocabulary.json"

    public var version = 1
    public var words: [WidgetWord]

    public init(words: [WidgetWord]) {
        self.words = words
    }

    /// The chosen word if it still exists, otherwise your most recently added word.
    public func resolve(selectedID: String?) -> WidgetWord? {
        if let selectedID, let chosen = words.first(where: { $0.id == selectedID }) {
            return chosen
        }
        return suggested().first
    }

    /// Most recently added first, for the widget's word picker.
    public func suggested() -> [WidgetWord] {
        words.sorted { $0.dateAdded > $1.dateAdded }
    }

    public func search(_ query: String) -> [WidgetWord] {
        let needle = VocabularyText.searchKey(query)
        guard !needle.isEmpty else { return suggested() }
        return suggested().filter { word in
            ([word.russian, word.meaning] + word.pronunciations.map(\.text))
                .contains { VocabularyText.searchKey($0).contains(needle) }
        }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }
}
