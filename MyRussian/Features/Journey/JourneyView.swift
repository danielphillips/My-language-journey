import Charts
import SwiftData
import SwiftUI
import MyRussianCore

enum JourneyRoute: Hashable {
    case history
    case roadmap
}

enum JourneySheet: Identifiable {
    case startSession
    case log(StudySessionDraft?)
    case edit(StudySession)
    case goal(LearningGoal)

    var id: String {
        switch self {
        case .startSession: "start"
        case .log: "log"
        case let .edit(session): "edit-\(session.id)"
        case .goal: "goal"
        }
    }
}

struct JourneyView: View {
    @Environment(\.modelContext) private var context
    @Environment(LiveTimerStore.self) private var timerStore
    @Query(sort: \StudySession.start, order: .reverse) private var sessions: [StudySession]
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @Query private var milestoneRecords: [MilestoneRecord]

    @State private var sheet: JourneySheet?
    @State private var unsavedSession: StudySessionDraft?
    @State private var saveError: String?
    @State private var savedCount = 0

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                if let goal = goals.first {
                    dashboard(goal: goal)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Journey")
            .toolbar { toolbar }
            .navigationDestination(for: JourneyRoute.self) { route in
                switch route {
                case .history: StudyHistoryView()
                case .roadmap: RoadmapView()
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .startSession: StartSessionSheet()
                case let .log(draft): LogSessionSheet(mode: .new(draft))
                case let .edit(session): LogSessionSheet(mode: .edit(session))
                case let .goal(goal): GoalEditorView(goal: goal)
                }
            }
            .alert("Session not saved", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } }), presenting: saveError) { _ in
                Button("Review") {
                    let draft = unsavedSession
                    saveError = nil
                    sheet = .log(draft)
                }
                Button("Discard", role: .destructive) {
                    saveError = nil
                    unsavedSession = nil
                }
            } message: { message in
                Text(message)
            }
            .sensoryFeedback(.success, trigger: savedCount)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let goal = goals.first {
                Button("Goal", systemImage: "slider.horizontal.3") { sheet = .goal(goal) }
                    .accessibilityIdentifier("journey.goal")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Start Session", systemImage: "timer") { sheet = .startSession }
                    .disabled(timerStore.timer.isActive)
                    .accessibilityIdentifier("journey.startSession")
                Button("Log Past Session", systemImage: "square.and.pencil") { sheet = .log(nil) }
                    .accessibilityIdentifier("journey.logPastSession")
            } label: {
                Label("Add", systemImage: "plus")
            }
            .accessibilityIdentifier("journey.add")
        }
    }

    @ViewBuilder
    private func dashboard(goal: LearningGoal) -> some View {
        let settings = goal.settings
        let now = Date.now
        let stats = StudyStatistics(sessions: sessions.map(\.draft), calendar: calendar)
        let progress = GoalProgress(
            goal: settings,
            totalStudied: stats.totalDuration,
            thisWeek: stats.duration(inWeekContaining: now),
            recentWeeklyAverage: stats.recentWeeklyAverage(endingWith: now, weeks: 4),
            now: now,
            calendar: calendar
        )
        let statuses = Dictionary(milestoneRecords.map { ($0.milestoneID, $0.status) }, uniquingKeysWith: { a, _ in a })
        let roadmap = RoadmapProgress(milestones: MilestoneCatalog.milestones(for: settings.level), statuses: statuses)

        LazyVStack(spacing: Theme.spacing) {
            GoalHeader(settings: settings, progress: progress)

            if timerStore.timer.isActive {
                LiveSessionCard(onStop: save)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            EffortCard(progress: progress)

            WeekCard(progress: progress, weeks: stats.weeklyTotals(endingWith: now, count: 8))

            PaceCard(progress: progress, settings: settings)

            NavigationLink(value: JourneyRoute.roadmap) {
                RoadmapSummaryCard(level: settings.level, progress: roadmap)
            }
            .buttonStyle(.plain)

            RecentSessionsCard(sessions: Array(sessions.prefix(4))) { session in
                sheet = .edit(session)
            }
        }
        .animation(.smooth, value: timerStore.timer.isActive)
    }

    private func save(_ draft: StudySessionDraft) {
        do {
            try StudyLog(context: context).log(draft)
            savedCount += 1
        } catch let error as StudySessionValidationError {
            unsavedSession = draft
            saveError = error.message
        } catch {
            unsavedSession = draft
            saveError = "Something went wrong saving this session."
        }
    }
}

// MARK: - Cards

private struct GoalHeader: View {
    let settings: GoalSettings
    let progress: GoalProgress

    private var countdown: String {
        switch progress.daysUntilExam {
        case 0: "Exam time"
        case 1: "Tomorrow"
        case ..<15: "\(progress.daysUntilExam) days to go"
        default: "\(Int(progress.weeksUntilExam)) weeks to go"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "мой путь · \(settings.level.torflName)")
            Text(settings.level.displayName)
                .font(.largeTitle.weight(.bold))
                .accessibilityIdentifier("journey.goalLevel")
            HStack {
                Label(settings.examDate.isMonthOnly ? "Exam \(settings.examDate.formatted())"
                                                    : settings.examDate.formatted(),
                      systemImage: "calendar")
                Spacer()
                Text(countdown).monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EffortCard: View {
    let progress: GoalProgress

    var body: some View {
        Card {
            HStack(spacing: 22) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: progress.fractionComplete)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.smooth(duration: 0.8), value: progress.fractionComplete)
                    VStack(spacing: 0) {
                        Text(progress.completedHours.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                        Text("hours").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 112, height: 112)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(DurationFormat.hours(progress.completedHours)) studied")

                VStack(alignment: .leading, spacing: 6) {
                    CardHeader(title: "Study hours", systemImage: "hourglass")
                    Text("of \(DurationFormat.hours(progress.estimatedHours)) estimated")
                        .font(.headline)
                        .accessibilityIdentifier("journey.estimate")
                    Text(progress.remainingHours > 0 ? "\(DurationFormat.hours(progress.remainingHours)) to go" : "Estimate reached")
                        .foregroundStyle(.secondary)
                    Text("Hours measure effort, not proficiency. The estimate is indicative.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct WeekCard: View {
    let progress: GoalProgress
    let weeks: [PeriodTotal]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "This week", systemImage: "calendar.day.timeline.left")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(DurationFormat.short(progress.thisWeekHours * 3600))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("journey.thisWeekValue")
                    Text("of \(DurationFormat.hours(progress.weeklyTargetHours)) target")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(progress.weeklyFraction, 1))
                    .tint(progress.weeklyFraction >= 1 ? .green : .accentColor)
                    .accessibilityLabel("Weekly target progress")

                Chart {
                    ForEach(weeks) { week in
                        BarMark(x: .value("Week", week.start, unit: .weekOfYear),
                                y: .value("Hours", week.hours))
                            .foregroundStyle(week.id == weeks.last?.id ? Color.accentColor : Color.accentColor.opacity(0.35))
                            .cornerRadius(5)
                    }
                    RuleMark(y: .value("Target", progress.weeklyTargetHours))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Target").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 120)
                .accessibilityLabel("Study hours for the last 8 weeks")
            }
        }
    }
}

private struct PaceCard: View {
    let progress: GoalProgress
    let settings: GoalSettings

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Pace", systemImage: "gauge.with.dots.needle.50percent")
                Label(progress.pace.title, systemImage: progress.pace.systemImage)
                    .font(.headline)
                    .foregroundStyle(progress.pace.color)
                if let required = progress.requiredWeeklyHours {
                    Text("\(DurationFormat.hours(required)) a week reaches \(DurationFormat.hours(progress.estimatedHours)) by \(settings.examDate.formatted()).")
                }
                Text("Recent average: \(DurationFormat.hours(progress.recentWeeklyAverageHours)) a week")
                    .foregroundStyle(.secondary)
                if !progress.weeklyTargetIsSufficient {
                    Label("Your \(DurationFormat.hours(progress.weeklyTargetHours)) weekly target is below the pace needed.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct RoadmapSummaryCard: View {
    let level: ProficiencyLevel
    let progress: RoadmapProgress

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardHeader(title: "Roadmap · \(level.code)", systemImage: "map")
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                if progress.milestones.isEmpty {
                    Text("A roadmap for \(level.code) isn’t in the app yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(progress.competencies) { competency in
                        HStack(spacing: 12) {
                            Image(systemName: competency.competency.systemImage)
                                .frame(width: 22)
                                .foregroundStyle(.tint)
                            Text(competency.competency.title)
                                .font(.subheadline)
                                .frame(width: 150, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            SegmentedBar(segments: MilestoneStatus.allCases.reversed().map {
                                SegmentedBar.Segment(id: $0.rawValue, value: Double(competency.count(of: $0)),
                                      color: $0 == .notStarted ? .clear : $0.color)
                            })
                            Text("\(competency.count(of: .comfortable) + competency.count(of: .demonstrated))/\(competency.total)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if let next = progress.upNext(limit: 1).first {
                        Label("Up next: \(next.title)", systemImage: "arrow.forward.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentShape(.rect)
    }
}

private struct RecentSessionsCard: View {
    let sessions: [StudySession]
    let onSelect: (StudySession) -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CardHeader(title: "Recent sessions", systemImage: "clock.arrow.circlepath")
                    NavigationLink("History", value: JourneyRoute.history)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("journey.history")
                }
                if sessions.isEmpty {
                    Text("No sessions yet. Start a timer, or log time you’ve already studied with +.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        Button { onSelect(session) } label: { SessionRow(session: session) }
                            .buttonStyle(.plain)
                        if session.id != sessions.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: StudySession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.category.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.category.title).font(.body.weight(.medium))
                Text(session.notes.isEmpty
                     ? session.start.formatted(.relative(presentation: .named))
                     : session.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(DurationFormat.short(session.duration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    JourneyView().previewEnvironment(sampleData: true)
}
