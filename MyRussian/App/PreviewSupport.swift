import SwiftData
import SwiftUI
import MyRussianCore

/// In-memory dependencies for SwiftUI previews (#Preview blocks compile in every configuration).
@MainActor
enum PreviewSupport {
    static func container(sampleData: Bool) -> ModelContainer {
        let container = try! AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let goal = GoalStore.currentGoal(in: context)
        goal.hasCompletedOnboarding = true
        guard sampleData else { return container }

        let now = Date.now
        let categories: [StudyCategory] = [.duolingo, .vocabulary, .grammar, .listening, .speaking]
        for day in 0..<40 where day % 3 != 2 {
            let start = Calendar.current.date(byAdding: .day, value: -day, to: now)!.addingTimeInterval(-3 * 3600)
            context.insert(StudySession(draft: StudySessionDraft(start: start, duration: Double(20 + (day * 7) % 50) * 60,
                                                                 category: categories[day % categories.count])))
        }

        let audio = try! AudioFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("PreviewAudio"))
        let service = VocabularyService(context: context, audioStore: audio)
        try? service.addWord(russian: "где", meaning: "where", confidence: .confident,
                             pronunciation: try? PronunciationNoteDraft(text: "Kadé", language: .french), topic: .essentials)
        try? service.addWord(russian: "женщины", meaning: "women", confidence: .recognise,
                             pronunciation: try? PronunciationNoteDraft(text: "Gente-chima", language: .brazilianPortuguese), topic: .people)
        try? service.addWord(russian: "спасибо", meaning: "thank you", confidence: .comfortable, topic: .greetings)
        try? service.addWord(russian: "здравствуйте", meaning: "hello (formal)", confidence: .learning, topic: .greetings)
        try? service.addWord(russian: "хлеб", meaning: "bread", confidence: .confident, topic: .food)
        MilestoneStore(context: context).setStatus(.demonstrated, for: MilestoneCatalog.milestones(for: .a1)[0])
        MilestoneStore(context: context).setStatus(.learning, for: MilestoneCatalog.milestones(for: .a1)[1])
        try? context.save()
        return container
    }

    static let environment: AppEnvironment = {
        let store = try! AudioFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("PreviewAudio"))
        return AppEnvironment(audioStore: store, recordingDevice: SimulatedRecordingDevice(), isUITesting: true)
    }()
}

extension View {
    @MainActor
    func previewEnvironment(sampleData: Bool = false) -> some View {
        self
            .modelContainer(PreviewSupport.container(sampleData: sampleData))
            .environment(PreviewSupport.environment)
            .environment(LiveTimerStore(defaults: UserDefaults(suiteName: "Preview") ?? .standard))
    }
}
