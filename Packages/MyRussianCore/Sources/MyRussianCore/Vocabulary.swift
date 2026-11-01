import Foundation

public enum ConfidenceLevel: Int, CaseIterable, Codable, Comparable, Sendable, Identifiable {
    case learning = 1, recognise, comfortable, confident

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .learning: "Learning"
        case .recognise: "Recognise"
        case .comfortable: "Comfortable"
        case .confident: "Confident"
        }
    }

    public var explanation: String {
        switch self {
        case .learning: "I’ve encountered it but haven’t retained it."
        case .recognise: "I understand it when I see or hear it."
        case .comfortable: "I can usually recall and use it."
        case .confident: "I can use it naturally without much effort."
        }
    }

    /// Filled-dot count used as a compact visual indicator (1–4).
    public var dots: Int { rawValue }

    /// Comfortable and Confident words form the active vocabulary.
    public var isActive: Bool { self >= .comfortable }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Anything that can be searched, sorted and counted as a vocabulary entry.
/// Implemented by the SwiftData model in the app and by `VocabularySnapshot` in tests.
public protocol VocabularyItem: Identifiable where ID: Hashable {
    var russian: String { get }
    var meaning: String { get }
    var confidence: ConfidenceLevel { get }
    var dateAdded: Date { get }
    var dateUpdated: Date { get }
    var pronunciationTexts: [String] { get }
}

public struct VocabularySnapshot: VocabularyItem, Hashable, Sendable {
    public let id: UUID
    public var russian: String
    public var meaning: String
    public var confidence: ConfidenceLevel
    public var dateAdded: Date
    public var dateUpdated: Date
    public var pronunciationTexts: [String]

    public init(id: UUID = UUID(), russian: String, meaning: String, confidence: ConfidenceLevel,
                dateAdded: Date, dateUpdated: Date, pronunciationTexts: [String] = []) {
        self.id = id
        self.russian = russian
        self.meaning = meaning
        self.confidence = confidence
        self.dateAdded = dateAdded
        self.dateUpdated = dateUpdated
        self.pronunciationTexts = pronunciationTexts
    }
}

public enum VocabularyText {
    /// The user's text, unchanged except for leading/trailing whitespace.
    public static func cleanedForStorage(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strict comparison key for duplicates and alphabetical order: case-insensitive, ignores
    /// stress marks and spacing, treats ё as е, but keeps distinct letters such as й.
    public static func matchKey(_ text: String) -> String {
        let stressMarks: Set<Unicode.Scalar> = ["\u{0301}", "\u{0300}"]
        let lowered = text.precomposedStringWithCanonicalMapping.lowercased().replacingOccurrences(of: "ё", with: "е")
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: lowered.unicodeScalars.filter { !stressMarks.contains($0) })
        return collapseWhitespace(String(scalars))
    }

    /// Permissive key for search: also ignores all other diacritics (so "kade" finds "Kadé").
    public static func searchKey(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: text.decomposedStringWithCanonicalMapping.lowercased().unicodeScalars
            .filter { !(0x0300...0x036F).contains($0.value) })
        return collapseWhitespace(String(scalars))
    }

    /// List-row subtitle: the meaning, then " • " and the first personal pronunciation (verbatim).
    public static func listSubtitle(meaning: String, pronunciations: [String]) -> String {
        guard let first = pronunciations.first(where: { !$0.allSatisfy(\.isWhitespace) }) else { return meaning }
        return meaning + " • " + first
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

public enum DuplicateCheck<ID: Hashable>: Equatable {
    case unique
    /// Same Russian text with a different meaning: a legitimate separate sense, allowed but worth showing.
    case sameWordDifferentMeaning([ID])
    case duplicate(ID)

    public var blocksSaving: Bool {
        if case .duplicate = self { true } else { false }
    }
}

public enum VocabularyDuplicateDetector {
    public static func check<Item: VocabularyItem>(
        russian: String, meaning: String, among items: [Item], excluding excludedID: Item.ID? = nil
    ) -> DuplicateCheck<Item.ID> {
        let russianKey = VocabularyText.matchKey(russian)
        let meaningKey = VocabularyText.matchKey(meaning)
        let sameWord = items.filter { $0.id != excludedID && VocabularyText.matchKey($0.russian) == russianKey }
        if let exact = sameWord.first(where: { VocabularyText.matchKey($0.meaning) == meaningKey }) {
            return .duplicate(exact.id)
        }
        return sameWord.isEmpty ? .unique : .sameWordDifferentMeaning(sameWord.map(\.id))
    }
}

public enum VocabularySort: String, CaseIterable, Codable, Sendable, Identifiable {
    case recentlyAdded, recentlyUpdated, alphabetical, confidence

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .recentlyAdded: "Recently Added"
        case .recentlyUpdated: "Recently Updated"
        case .alphabetical: "А–Я"
        case .confidence: "Confidence"
        }
    }
}

public struct VocabularyQuery: Equatable, Sendable {
    public var searchText: String
    /// Empty means all levels.
    public var confidences: Set<ConfidenceLevel>
    public var sort: VocabularySort

    public init(searchText: String = "", confidences: Set<ConfidenceLevel> = [], sort: VocabularySort = .recentlyAdded) {
        self.searchText = searchText
        self.confidences = confidences
        self.sort = sort
    }

    public func apply<Item: VocabularyItem>(to items: [Item]) -> [Item] {
        let needle = VocabularyText.searchKey(searchText)
        let filtered = items.filter { item in
            (confidences.isEmpty || confidences.contains(item.confidence))
                && (needle.isEmpty || ([item.russian, item.meaning] + item.pronunciationTexts)
                    .contains { VocabularyText.searchKey($0).contains(needle) })
        }
        return filtered.sorted(by: areInIncreasingOrder)
    }

    private func areInIncreasingOrder<Item: VocabularyItem>(_ a: Item, _ b: Item) -> Bool {
        switch sort {
        case .recentlyAdded:
            return a.dateAdded > b.dateAdded
        case .recentlyUpdated:
            return a.dateUpdated != b.dateUpdated ? a.dateUpdated > b.dateUpdated : a.dateAdded > b.dateAdded
        case .alphabetical:
            return Self.alphabetical(a, b)
        case .confidence:
            return a.confidence != b.confidence ? a.confidence < b.confidence : Self.alphabetical(a, b)
        }
    }

    /// Unicode scalar order of the match key follows the Russian alphabet once ё is folded into е.
    private static func alphabetical<Item: VocabularyItem>(_ a: Item, _ b: Item) -> Bool {
        let keyA = VocabularyText.matchKey(a.russian), keyB = VocabularyText.matchKey(b.russian)
        return keyA != keyB ? keyA.unicodeScalars.lexicographicallyPrecedes(keyB.unicodeScalars) : a.dateAdded < b.dateAdded
    }
}

public struct VocabularyGrowthPoint: Equatable, Sendable, Identifiable {
    public let weekStart: Date
    public let total: Int
    public var id: Date { weekStart }
}

public struct VocabularyStatistics<Item: VocabularyItem> {
    private let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    public var total: Int { items.count }

    public func count(of level: ConfidenceLevel) -> Int {
        items.filter { $0.confidence == level }.count
    }

    public var activeCount: Int {
        items.filter { $0.confidence.isActive }.count
    }

    public func recentlyAdded(limit: Int) -> [Item] {
        Array(items.sorted { $0.dateAdded > $1.dateAdded }.prefix(limit))
    }

    /// Cumulative number of entries at the end of each of the last `weeks` weeks, oldest first.
    public func weeklyGrowth(endingWith date: Date, weeks: Int, calendar: Calendar) -> [VocabularyGrowthPoint] {
        guard weeks > 0, let current = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<weeks).reversed().map { offset in
            let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: current)!
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return VocabularyGrowthPoint(weekStart: start, total: items.filter { $0.dateAdded < end }.count)
        }
    }
}
