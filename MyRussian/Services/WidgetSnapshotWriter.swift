import Foundation
import WidgetKit
import MyRussianCore

/// Shares a small, read-only copy of your vocabulary with the lock-screen widget via the App Group.
@MainActor
enum WidgetSnapshotWriter {
    static let appGroup = "group.com.danielphillips.MyRussian"

    static var sharedDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    /// Writes the snapshot; returns `true` if the file content changed.
    @discardableResult
    static func write(words: [VocabularyWord], to directory: URL) throws -> Bool {
        let snapshot = WidgetSnapshot(words: words.map { word in
            WidgetWord(item: word, pronunciations: word.sortedPronunciationNotes.map {
                WidgetPronunciation(text: $0.text, flag: $0.flag)
            })
        })
        let data = try snapshot.encoded()
        let url = directory.appendingPathComponent(WidgetSnapshot.fileName)
        if let existing = try? Data(contentsOf: url), existing == data { return false }
        try data.write(to: url, options: .atomic)
        return true
    }

    /// Updates the shared copy and asks the widget to refresh only when something changed.
    static func update(words: [VocabularyWord]) {
        guard let directory = sharedDirectory else { return } // App Group not available (e.g. unsigned build)
        if (try? write(words: words, to: directory)) == true {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
