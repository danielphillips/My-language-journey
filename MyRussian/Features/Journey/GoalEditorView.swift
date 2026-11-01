import SwiftData
import SwiftUI
import MyRussianCore

/// Shared goal fields as form sections, used in onboarding and settings.
struct GoalFormSections: View {
    @Binding var settings: GoalSettings
    private let calendar = Calendar.current

    private var exactDateKnown: Binding<Bool> {
        Binding(
            get: { !settings.examDate.isMonthOnly },
            set: { exact in
                let target = settings.examDate.targetDate(in: calendar)
                if exact {
                    settings.examDate = .day(target)
                } else {
                    let c = calendar.dateComponents([.year, .month], from: target)
                    settings.examDate = .month(year: c.year ?? 2027, month: c.month ?? 5)
                }
            }
        )
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.month, from: settings.examDate.targetDate(in: calendar)) },
            set: { settings.examDate = .month(year: yearBinding.wrappedValue, month: $0) }
        )
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.year, from: settings.examDate.targetDate(in: calendar)) },
            set: { settings.examDate = .month(year: $0, month: monthBinding.wrappedValue) }
        )
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: { settings.examDate.targetDate(in: calendar) },
            set: { settings.examDate = .day($0) }
        )
    }

    private var levelBinding: Binding<ProficiencyLevel> {
        Binding(get: { settings.level }, set: { settings.changeLevel(to: $0) })
    }

    var body: some View {
            Section {
                Picker("Target level", selection: levelBinding) {
                    ForEach(ProficiencyLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .accessibilityIdentifier("goal.level")
            } header: {
                Text("Qualification")
            } footer: {
                Text("TORFL (ТРКИ) levels broadly correspond to CEFR A1–C2.")
            }

            Section("Exam") {
                Toggle("I know the exact date", isOn: exactDateKnown)
                if settings.examDate.isMonthOnly {
                    Picker("Month", selection: monthBinding) {
                        ForEach(1...12, id: \.self) { month in
                            Text(calendar.monthSymbols[month - 1]).tag(month)
                        }
                    }
                    Picker("Year", selection: yearBinding) {
                        let current = calendar.component(.year, from: .now)
                        ForEach(current...(current + 6), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                } else {
                    DatePicker("Date", selection: dayBinding, displayedComponents: .date)
                }
            }

            Section {
                Stepper(value: $settings.weeklyTargetHours, in: 0.5...40, step: 0.5) {
                    LabeledContent("Weekly target", value: DurationFormat.hours(settings.weeklyTargetHours))
                }
                Stepper(value: $settings.estimatedHours, in: 0...2000, step: 5) {
                    LabeledContent("Estimated study", value: DurationFormat.hours(settings.estimatedHours))
                }
            } header: {
                Text("Study hours")
            } footer: {
                if settings.level.defaultEstimatedHours == nil {
                    Text("There’s no verified hour estimate for \(settings.level.code) in the app. Enter your own planning figure.")
                } else {
                    Text("An indicative planning figure, not a formal requirement. Adjust it as you learn.")
                }
            }
    }
}

struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let goal: LearningGoal
    @State private var settings: GoalSettings

    init(goal: LearningGoal) {
        self.goal = goal
        _settings = State(initialValue: goal.settings)
    }

    var body: some View {
        NavigationStack {
            Form { GoalFormSections(settings: $settings) }
                .navigationTitle("Goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") {
                            goal.settings = settings
                            try? context.save()
                            dismiss()
                        }
                        .accessibilityIdentifier("goal.save")
                    }
                }
        }
    }
}
