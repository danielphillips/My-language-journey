import SwiftData
import SwiftUI
import MyRussianCore

struct RoadmapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @Query private var records: [MilestoneRecord]
    @State private var changes = 0

    private var level: ProficiencyLevel { goals.first?.settings.level ?? .a1 }

    var body: some View {
        let statuses = Dictionary(records.map { ($0.milestoneID, $0.status) }, uniquingKeysWith: { a, _ in a })
        let progress = RoadmapProgress(milestones: MilestoneCatalog.milestones(for: level), statuses: statuses)

        List {
            if progress.milestones.isEmpty {
                ContentUnavailableView(
                    "No \(level.code) roadmap yet",
                    systemImage: "map",
                    description: Text("The app only includes a roadmap for A1 so far. Your study hours and vocabulary still count.")
                )
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        SegmentedBar(segments: MilestoneStatus.allCases.reversed().map {
                            SegmentedBar.Segment(id: $0.rawValue, value: Double(progress.count(of: $0)),
                                                 color: $0 == .notStarted ? .clear : $0.color)
                        }, height: 12)
                        HStack(spacing: 14) {
                            ForEach(MilestoneStatus.allCases) { status in
                                Label("\(progress.count(of: status))", systemImage: status.systemImage)
                                    .foregroundStyle(status.color)
                                    .font(.subheadline.monospacedDigit())
                                    .accessibilityLabel("\(status.title): \(progress.count(of: status))")
                            }
                        }
                        Text("\(progress.remainingCount) of \(progress.milestones.count) objectives still to secure")
                            .font(.headline)
                    }
                    .padding(.vertical, 6)
                } footer: {
                    Text("These are practical learning objectives written for this app, not the official TORFL syllabus. Mark an objective Comfortable or Demonstrated once you’ve secured it.")
                }

                ForEach(progress.competencies) { competency in
                    Section {
                        ForEach(competency.milestones) { milestone in
                            MilestoneRow(milestone: milestone, status: progress.status(of: milestone)) { status in
                                MilestoneStore(context: context).setStatus(status, for: milestone)
                                changes += 1
                            }
                        }
                    } header: {
                        HStack {
                            Label(competency.competency.title, systemImage: competency.competency.systemImage)
                            Spacer()
                            Text("\(competency.count(of: .comfortable) + competency.count(of: .demonstrated))/\(competency.total)")
                                .monospacedDigit()
                        }
                    } footer: {
                        if let subtest = competency.competency.torflSubtest {
                            Text("Prepares for the TORFL \(subtest) subtest.")
                        } else {
                            Text("Foundation for every TORFL subtest.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Roadmap · \(level.code)")
        .sensoryFeedback(.selection, trigger: changes)
    }
}

private struct MilestoneRow: View {
    let milestone: Milestone
    let status: MilestoneStatus
    let onChange: (MilestoneStatus) -> Void

    var body: some View {
        Menu {
            Picker("Status", selection: Binding(get: { status }, set: onChange)) {
                ForEach(MilestoneStatus.allCases) { item in
                    Label(item.title, systemImage: item.systemImage).tag(item)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: status.systemImage)
                    .font(.title3)
                    .foregroundStyle(status.color)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title).foregroundStyle(.primary)
                    Text(milestone.detail).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(status.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(status.color)
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("\(milestone.title), \(status.title)")
        .accessibilityHint("Changes the status")
        .accessibilityIdentifier("milestone.\(milestone.id)")
    }
}
