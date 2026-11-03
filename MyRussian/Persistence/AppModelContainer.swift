import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([
        LearningGoal.self,
        StudySession.self,
        MilestoneRecord.self,
        VocabularyWord.self,
        PronunciationNote.self,
        AudioRecording.self,
        LetterRecording.self
    ])

    /// - Parameters:
    ///   - inMemory: isolated, throwaway store (tests and previews).
    ///   - url: explicit on-disk location (UI tests, relaunch tests); `nil` uses the default store.
    static func make(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            // A unique name keeps every in-memory container isolated from the others.
            configuration = ModelConfiguration(UUID().uuidString, schema: schema,
                                               isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
