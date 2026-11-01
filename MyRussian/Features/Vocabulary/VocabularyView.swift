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
    private var isSearching: Bool { !query.searchText.isEmpty }

    private var listTitle: String {
        if let level = query.confidenceFilter { return level.title }
        return isFiltering ? "Results" : query.sort.title
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !isSearching && !words.isEmpty {
                    Section {
                        VocabularyOverview(words: words, level: goals.first?.settings.level ?? .a1)
                    }
                }

                if !words.isEmpty {
                    Section {
                        ConfidenceSegmentedControl(selection: $query.confidenceFilter,
                                                   counts: VocabularyStatistics(items: words).distribution)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
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
                        Text(isFiltering ? "\(listTitle) · \(results.count) of \(words.count)" : listTitle)
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
                    SortMenu(sort: $query.sort)
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
                } else if isSearching && query.apply(to: words).isEmpty {
                    ContentUnavailableView.search(text: query.searchText)
                } else if let level = query.confidenceFilter, query.apply(to: words).isEmpty {
                    ContentUnavailableView("No \(level.title) words yet", systemImage: "line.3.horizontal.decrease",
                                           description: Text(level.explanation))
                }
            }
            .sheet(isPresented: $addingWord) {
                AddWordSheet()
            }
        }
    }
}

private struct SortMenu: View {
    @Binding var sort: VocabularySort

    var body: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(VocabularySort.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("vocabulary.sort")
    }
}

/// "All" plus one segment per confidence level; selecting one filters the list.
private struct ConfidenceSegmentedControl: View {
    @Binding var selection: ConfidenceLevel?
    let counts: [ConfidenceCount]

    var body: some View {
        HStack(spacing: 4) {
            segment(title: "All", color: .accentColor, level: nil)
            ForEach(counts) { item in
                segment(title: item.level.title, color: item.level.color, level: item.level)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func segment(title: String, color: Color, level: ConfidenceLevel?) -> some View {
        let isSelected = selection == level
        return Button {
            withAnimation(.snappy) { selection = level }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(.horizontal, 2)
                .foregroundStyle(isSelected ? Color.white : color)
                .background(isSelected ? color : Color.clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.map { "\($0.title), \(counts.first { $0.level == level }?.count ?? 0) words" } ?? "All words")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("segment.\(level?.title.lowercased() ?? "all")")
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

            Chart(stats.distribution) { item in
                BarMark(x: .value("Confidence", item.level.title), y: .value("Words", Double(item.count)))
                    .foregroundStyle(item.level.color.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(item.count)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(item.level.color)
                    }
            }
            .chartXScale(domain: ConfidenceLevel.allCases.map(\.title))
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...max(Double(stats.distribution.map(\.count).max() ?? 0) * 1.25, 1))
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption)
                }
            }
            .frame(height: 150)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Words by confidence")
            .accessibilityValue(stats.distribution.map { "\($0.level.title) \($0.count)" }.joined(separator: ", "))

            let growth = stats.weeklyGrowth(endingWith: .now, weeks: 12, calendar: .current)
            if stats.total > 1 {
                Text("Growth · last 12 weeks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
