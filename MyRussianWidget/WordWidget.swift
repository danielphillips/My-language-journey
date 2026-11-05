import SwiftUI
import WidgetKit
import MyRussianCore

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord?
}

struct WordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, word: .sample)
    }

    func snapshot(for configuration: SelectWordIntent, in context: Context) async -> WordEntry {
        let word = SharedVocabulary.load().word(for: configuration.word.choice, at: .now, calendar: .current)
        return WordEntry(date: .now, word: word ?? (context.isPreview ? .sample : nil))
    }

    func timeline(for configuration: SelectWordIntent, in context: Context) async -> Timeline<WordEntry> {
        let snapshot = SharedVocabulary.load()
        let choice = configuration.word.choice
        let calendar = Calendar.current
        let now = Date.now

        guard choice == .random else {
            // A chosen word never changes by itself; the app reloads the widget when your vocabulary changes.
            return Timeline(entries: [WordEntry(date: now, word: snapshot.word(for: choice, at: now, calendar: calendar))],
                            policy: .never)
        }

        // Random word: the current slot plus the next three 05:00/17:00 changes (two days), then ask again.
        var entries = [WordEntry(date: now, word: snapshot.word(for: .random, at: now, calendar: calendar))]
        var next = WordRotation.nextSlotStart(after: now, calendar: calendar)
        for _ in 0..<3 {
            entries.append(WordEntry(date: next, word: snapshot.word(for: .random, at: next, calendar: calendar)))
            next = WordRotation.nextSlotStart(after: next, calendar: calendar)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WordWidget", intent: SelectWordIntent.self, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Russian Word")
        .description("A word from your vocabulary with your own pronunciation.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        if let word = entry.word {
            switch family {
            case .accessoryInline:
                Text(verbatim: word.inlineText)
            default:
                rectangular(word)
            }
        } else {
            switch family {
            case .accessoryInline:
                Text("My Russian")
            default:
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Russian").font(.headline).widgetAccentable()
                    Text("Add a word in the app, then choose it here.").font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func rectangular(_ word: WidgetWord) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: word.russian)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.4) // long words like Потрясающе shrink to fit instead of truncating
                .allowsTightening(true)
                .widgetAccentable()
            if let line = word.lockScreenPronunciationLine {
                // Your own spelling, exactly as you typed it.
                Text(verbatim: line)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
            }
            Text(verbatim: word.meaning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension WidgetWord {
    static let sample = WidgetWord(id: "sample", russian: "где", meaning: "where",
                                   pronunciations: [WidgetPronunciation(text: "Kadé", flag: "🇫🇷")],
                                   dateAdded: .now)
}

#Preview(as: .accessoryRectangular) {
    WordWidget()
} timeline: {
    WordEntry(date: .now, word: .sample)
}
