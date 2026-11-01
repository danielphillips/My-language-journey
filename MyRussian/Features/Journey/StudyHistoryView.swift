import Charts
import SwiftData
import SwiftUI
import MyRussianCore

/// Study history and insights: trends, consistency, breakdown and every session.
struct StudyHistoryView: View {
    enum Period: String, CaseIterable, Identifiable {
        case weeks = "Weeks", months = "Months"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \StudySession.start, order: .reverse) private var sessions: [StudySession]
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @State private var period: Period = .weeks
    @State private var editing: StudySession?

    private let calendar = Calendar.current

    private var weeklyTarget: Double { goals.first?.weeklyTargetHours ?? 0 }

    var body: some View {
        let now = Date.now
        let stats = StudyStatistics(sessions: sessions.map(\.draft), calendar: calendar)
        let month = calendar.dateInterval(of: .month, for: now)!

        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                trendChart(stats: stats, now: now)
            }

            Section("Totals") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                    GridRow {
                        StatTile(title: "All time", value: DurationFormat.short(stats.totalDuration))
                        StatTile(title: "This month", value: DurationFormat.short(stats.duration(in: month)))
                    }
                    GridRow {
                        StatTile(title: "Active days this month", value: "\(stats.activeDays(in: month))")
                        let attainment = stats.weeklyAttainment(targetHours: weeklyTarget, endingWith: now, count: 8)
                        StatTile(title: "Weekly target met", value: "\(attainment.filter(\.met).count) of 8 weeks")
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                ConsistencyRow(attainment: stats.weeklyAttainment(targetHours: weeklyTarget, endingWith: now, count: 8))
            } header: {
                Text("Weekly goal")
            } footer: {
                Text("Each ring is one week. A full ring means you reached \(DurationFormat.hours(weeklyTarget)).")
            }

            let breakdown = stats.categoryBreakdown()
            if !breakdown.isEmpty {
                Section("What you studied") {
                    CategoryBreakdownChart(breakdown: breakdown)
                }
            }

            ForEach(groupedByWeek(), id: \.start) { group in
                Section(group.title) {
                    ForEach(group.sessions) { session in
                        Button { editing = session } label: { SessionRow(session: session) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for index in offsets { StudyLog(context: context).delete(group.sessions[index]) }
                    }
                }
            }
        }
        .navigationTitle("History")
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView("No study sessions yet", systemImage: "clock",
                                       description: Text("Sessions you time or log will appear here."))
            }
        }
        .sheet(item: $editing) { session in
            LogSessionSheet(mode: .edit(session))
        }
    }

    @ViewBuilder
    private func trendChart(stats: StudyStatistics, now: Date) -> some View {
        let totals = period == .weeks
            ? stats.weeklyTotals(endingWith: now, count: 12)
            : stats.monthlyTotals(endingWith: now, count: 6)
        let unit: Calendar.Component = period == .weeks ? .weekOfYear : .month

        Chart {
            ForEach(totals) { total in
                BarMark(x: .value("Period", total.start, unit: unit), y: .value("Hours", total.hours))
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(5)
            }
            if period == .weeks, weeklyTarget > 0 {
                RuleMark(y: .value("Target", weeklyTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxisLabel("hours")
        .chartXAxis {
            AxisMarks(values: .stride(by: unit, count: period == .weeks ? 3 : 1)) {
                AxisValueLabel(format: period == .weeks ? .dateTime.day().month(.abbreviated) : .dateTime.month(.abbreviated))
            }
        }
        .frame(height: 190)
        .padding(.vertical, 8)
        .animation(.smooth, value: period)
    }

    private struct WeekGroup {
        let start: Date
        let title: String
        let sessions: [StudySession]
    }

    private func groupedByWeek() -> [WeekGroup] {
        let groups = Dictionary(grouping: sessions) { calendar.dateInterval(of: .weekOfYear, for: $0.start)!.start }
        return groups.keys.sorted(by: >).map { start in
            let total = groups[start]!.reduce(0) { $0 + $1.duration }
            let title = "Week of \(start.formatted(.dateTime.day().month(.abbreviated))) · \(DurationFormat.short(total))"
            return WeekGroup(start: start, title: title, sessions: groups[start]!)
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ConsistencyRow: View {
    let attainment: [WeekAttainment]

    var body: some View {
        HStack {
            ForEach(attainment) { week in
                VStack(spacing: 6) {
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: min(week.fraction, 1))
                            .stroke(week.met ? Color.green : Color.accentColor,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        if week.met {
                            Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.green)
                        }
                    }
                    .frame(width: 28, height: 28)
                    Text(week.weekStart.formatted(.dateTime.day()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement()
                .accessibilityLabel("Week of \(week.weekStart.formatted(date: .abbreviated, time: .omitted)): \(DurationFormat.short(week.duration))\(week.met ? ", target met" : "")")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CategoryBreakdownChart: View {
    let breakdown: [CategoryTotal]

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Chart(breakdown) { item in
                SectorMark(angle: .value("Hours", item.hours), innerRadius: .ratio(0.62), angularInset: 1.5)
                    .cornerRadius(3)
                    .foregroundStyle(by: .value("Category", item.category.title))
            }
            .chartLegend(.hidden)
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(breakdown.prefix(5)) { item in
                    HStack {
                        Text(item.category.title).font(.subheadline)
                        Spacer()
                        Text(DurationFormat.short(item.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
}
