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

/// A vocabulary word you can pick when editing the widget.
struct WordEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Word"
    static let defaultQuery = WordQuery()

    let id: String
    let russian: String
    let meaning: String

    init(_ word: WidgetWord) {
        id = word.id
        russian = word.russian
        meaning = word.meaning
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(russian)", subtitle: "\(meaning)")
    }
}

struct WordQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [WordEntity] {
        SharedVocabulary.load().words.filter { identifiers.contains($0.id) }.map(WordEntity.init)
    }

    func entities(matching string: String) async throws -> [WordEntity] {
        SharedVocabulary.load().search(string).map(WordEntity.init)
    }

    func suggestedEntities() async throws -> [WordEntity] {
        SharedVocabulary.load().suggested().map(WordEntity.init)
    }
}

struct SelectWordIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose a Word"
    static let description = IntentDescription("Pick a word from your vocabulary to show with your own pronunciation.")

    @Parameter(title: "Word")
    var word: WordEntity?
}
