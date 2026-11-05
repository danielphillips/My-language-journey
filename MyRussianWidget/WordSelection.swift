import AppIntents
import Foundation
import MyRussianCore

/// Reads the read-only vocabulary copy the app writes into the shared App Group container.
enum SharedVocabulary {
    static let appGroup = "group.com.danielphillips.MyRussian"

    static func load() -> WidgetSnapshot {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup),
              let data = try? Data(contentsOf: directory.appendingPathComponent(WidgetSnapshot.fileName)),
              let snapshot = try? WidgetSnapshot.decode(data)
        else { return WidgetSnapshot(words: []) }
        return snapshot
    }
}

/// A vocabulary word you can pick when editing the widget, or the special "Random word".
struct WordEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Word"
    static let defaultQuery = WordQuery()
    static let randomID = "random"
    static let random = WordEntity(id: randomID, russian: "Random word", meaning: "A new word every morning and evening")

    let id: String
    let russian: String
    let meaning: String

    init(_ word: WidgetWord) {
        self.init(id: word.id, russian: word.russian, meaning: word.meaning)
    }

    private init(id: String, russian: String, meaning: String) {
        self.id = id
        self.russian = russian
        self.meaning = meaning
    }

    var displayRepresentation: DisplayRepresentation {
        if id == Self.randomID {
            return DisplayRepresentation(title: "\(russian)", subtitle: "\(meaning)", image: .init(systemName: "shuffle"))
        }
        return DisplayRepresentation(title: "\(russian)", subtitle: "\(meaning)")
    }
}

extension Optional where Wrapped == WordEntity {
    /// No choice, or "Random word", means the rotating random word.
    var choice: WidgetWordChoice {
        guard let entity = self, entity.id != WordEntity.randomID else { return .random }
        return .word(id: entity.id)
    }
}

struct WordQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [WordEntity] {
        let words = SharedVocabulary.load().words.filter { identifiers.contains($0.id) }.map(WordEntity.init)
        return identifiers.contains(WordEntity.randomID) ? [.random] + words : words
    }

    func entities(matching string: String) async throws -> [WordEntity] {
        let words = SharedVocabulary.load().search(string).map(WordEntity.init)
        let wantsRandom = string.isEmpty || "random".localizedCaseInsensitiveContains(string)
        return wantsRandom ? [.random] + words : words
    }

    /// "Random word" first, then your words, newest first.
    func suggestedEntities() async throws -> [WordEntity] {
        [.random] + SharedVocabulary.load().suggested().map(WordEntity.init)
    }
}

struct SelectWordIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose a Word"
    static let description = IntentDescription(
        "Pick a word to show with your own pronunciation, or Random word for a new one every morning and evening.")

    /// Empty (the default) also means Random word.
    @Parameter(title: "Word")
    var word: WordEntity?
}
