import SwiftData
import SwiftUI

struct RootView: View {
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @Query private var words: [VocabularyWord]
    @Environment(\.scenePhase) private var scenePhase

    /// Changes whenever a word, its meaning or its pronunciation notes change.
    private var widgetSignature: [String] {
        words.map { "\($0.id)|\($0.dateUpdated.timeIntervalSince1970)|\($0.pronunciationNotes?.count ?? 0)" }
    }

    private var needsOnboarding: Bool {
        goals.first?.hasCompletedOnboarding != true
    }

    var body: some View {
        TabView {
            Tab("Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                JourneyView()
            }
            Tab("Vocabulary", systemImage: "character.book.closed") {
                VocabularyView()
            }
            Tab("Alphabet", systemImage: "character") {
                AlphabetView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .dismissesKeyboardOnTapOutside()
        .onAppear { WidgetSnapshotWriter.update(words: words) }
        .onChange(of: widgetSignature) { WidgetSnapshotWriter.update(words: words) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { WidgetSnapshotWriter.update(words: words) }
        }
        .fullScreenCover(isPresented: .constant(needsOnboarding)) {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}
