import Charts
import SwiftData
import SwiftUI
import MyRussianCore

struct VocabularyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Query(sort: \VocabularyWord.dateAdded, order: .reverse) private var words: [VocabularyWord]
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]

    @State private var query = VocabularyQuery()
    @State private var addingWord = false
    @State private var path: [VocabularyWord] = []

    private var service: VocabularyService { VocabularyService(context: context, audioStore: app.audioStore) }

    private var isFiltering: Bool { !query.searchText.isEmpty || !query.confidences.isEmpty }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !isFiltering && !words.isEmpty {
                    Section {
                        VocabularyOverview(words: words, level: goals.first?.settings.level ?? .a1)
                    }
                }

                let results = query.apply(to: words)
                Section {
                    ForEach(results) { word in
                        NavigationLink(value: word) {
                            WordRow(word: word)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { service.delete(word) }
                        }
                        .contextMenu {
                            Picker("Confidence", selection: Binding(get: { word.confidence },
                                                                    set: { service.setConfidence($0, for: word) })) {
                                ForEach(ConfidenceLevel.allCases) { Text($0.title).tag($0) }
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) { service.delete(word) }
                        }
                    }
                } header: {
                    if !words.isEmpty {
                        Text(isFiltering ? "\(results.count) of \(words.count)" : query.sort.title)
                    }
                }
            }
            .navigationTitle("Vocabulary")
            .searchable(text: $query.searchText, prompt: "Russian, English or your spelling")
            .navigationDestination(for: VocabularyWord.self) { word in
                WordDetailView(word: word)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FilterMenu(query: $query)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Word", systemImage: "plus") { addingWord = true }
                        .accessibilityIdentifier("vocabulary.add")
                }
            }
            .overlay {
                if words.isEmpty {
                    ContentUnavailableView {
                        Label("Your words live here", systemImage: "character.book.closed")
                    } description: {
                        Text("Add Russian words and phrases as you meet them, with your own pronunciation notes and recordings.")
                    } actions: {
                        Button("Add Your First Word") { addingWord = true }
                            .buttonStyle(.glassProminent)
                    }
                } else if isFiltering && query.apply(to: words).isEmpty {
                    ContentUnavailableView.search(text: query.searchText)
                }
            }
            .sheet(isPresented: $addingWord) {
                AddWordSheet()
            }
        }
    }
}

private struct FilterMenu: View {
    @Binding var query: VocabularyQuery

    var body: some View {
        Menu {
            Picker("Sort", selection: $query.sort) {
                ForEach(VocabularySort.allCases) { Text($0.title).tag($0) }
            }
            Section("Show") {
                ForEach(ConfidenceLevel.allCases) { level in
                    Toggle(level.title, isOn: Binding(
                        get: { query.confidences.contains(level) },
                        set: { isOn in
                            if isOn { query.confidences.insert(level) } else { query.confidences.remove(level) }
                        }
                    ))
                }
                if !query.confidences.isEmpty {
                    Button("Show All", systemImage: "xmark.circle") { query.confidences = [] }
                }
            }
        } label: {
            Label("Sort and Filter", systemImage: query.confidences.isEmpty
                  ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityIdentifier("vocabulary.filter")
    }
}

struct WordRow: View {
    let word: VocabularyWord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(word.russian)
                    .font(Theme.russian(.title3))
                Text(verbatim: VocabularyText.listSubtitle(meaning: word.meaning,
                                                          pronunciations: word.sortedPronunciationNotes.map(\.text)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    let flags = Array(Set(word.sortedPronunciationNotes.map(\.flag))).sorted()
                    Text(flags.joined()).font(.caption)
                    if !(word.recordings ?? []).isEmpty {
                        Image(systemName: "waveform").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ConfidenceDots(level: word.confidence)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Header dashboard: counts by confidence, active vocabulary, growth and recent additions.
private struct VocabularyOverview: View {
    let words: [VocabularyWord]
    let level: ProficiencyLevel

    var body: some View {
        let stats = VocabularyStatistics(items: words)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(stats.total)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("vocabulary.total")
                    Text(stats.total == 1 ? "entry" : "entries").foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(stats.activeCount)")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .foregroundStyle(.teal)
                    Text("active · Comfortable + Confident")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                ForEach(ConfidenceLevel.allCases) { level in
                    VStack(spacing: 2) {
                        Text("\(stats.count(of: level))")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text(level.title)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(level.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(level.color.opacity(0.1), in: .rect(cornerRadius: 14))
                    .accessibilityElement(children: .combine)
                }
            }

            let growth = stats.weeklyGrowth(endingWith: .now, weeks: 12, calendar: .current)
            if stats.total > 1 {
                Chart(growth) { point in
                    AreaMark(x: .value("Week", point.weekStart, unit: .weekOfYear), y: .value("Words", point.total))
                        .foregroundStyle(Color.accentColor.opacity(0.15).gradient)
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Week", point.weekStart, unit: .weekOfYear), y: .value("Words", point.total))
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .frame(height: 70)
                .accessibilityLabel("Vocabulary growth over the last 12 weeks")
            }

            if let reference = level.lexicalMinimumReference {
                Text("For context: the TORFL \(level.code) lexical minimum is often cited as about \(reference) items. Your personal list isn’t checked against it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    VocabularyView().previewEnvironment(sampleData: true)
}
