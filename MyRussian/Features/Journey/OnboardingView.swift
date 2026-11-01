import SwiftData
import SwiftUI
import MyRussianCore

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var settings = GoalSettings.initial

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Мой русский")
                            .font(Theme.russian(.largeTitle, weight: .bold))
                            .foregroundStyle(.tint)
                        Text("A personal record of your effort, your skills and the words you really know.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.level.displayName)
                            .font(.title2.weight(.semibold))
                        Text("TORFL \(settings.level.torflName) · Exam \(settings.examDate.formatted())")
                            .foregroundStyle(.secondary)
                        Text("\(DurationFormat.hours(settings.weeklyTargetHours)) a week towards \(DurationFormat.hours(settings.estimatedHours))")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your goal")
                }

                GoalFormSections(settings: $settings)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let goal = GoalStore.currentGoal(in: context)
                    goal.settings = settings
                    goal.hasCompletedOnboarding = true
                    try? context.save()
                } label: {
                    Text("Start My Journey").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding()
                .accessibilityIdentifier("onboarding.start")
            }
        }
    }
}

#Preview {
    OnboardingView().previewEnvironment()
}
