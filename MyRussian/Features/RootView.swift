import SwiftData
import SwiftUI

struct RootView: View {
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]

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
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .dismissesKeyboardOnTapOutside()
        .fullScreenCover(isPresented: .constant(needsOnboarding)) {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}
