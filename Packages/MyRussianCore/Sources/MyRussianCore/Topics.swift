import Foundation

/// Everyday themes for grouping vocabulary, loosely following the topics of an A1 course.
/// App-authored; raw values are persisted, so never change them.
public enum VocabularyTopic: String, CaseIterable, Codable, Sendable, Identifiable {
    case greetings, essentials, people, numbers, time, food, home, city, travel, shopping, work,
         body, nature, animals, leisure, describing, other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .greetings: "Greetings & Courtesy"
        case .essentials: "Questions & Essentials"
        case .people: "People & Family"
        case .numbers: "Numbers"
        case .time: "Time & Dates"
        case .food: "Food & Drink"
        case .home: "Home"
        case .city: "City & Places"
        case .travel: "Travel & Transport"
        case .shopping: "Shopping & Money"
        case .work: "Work & Study"
        case .body: "Body & Health"
        case .nature: "Nature & Weather"
        case .animals: "Animals"
        case .leisure: "Hobbies & Leisure"
        case .describing: "Colours & Describing"
        case .other: "Other"
        }
    }

    /// SF Symbol name.
    public var systemImage: String {
        switch self {
        case .greetings: "hand.wave"
        case .essentials: "questionmark.bubble"
        case .people: "person.2"
        case .numbers: "number"
        case .time: "calendar"
        case .food: "fork.knife"
        case .home: "house"
        case .city: "building.2"
        case .travel: "tram"
        case .shopping: "cart"
        case .work: "briefcase"
        case .body: "heart"
        case .nature: "leaf"
        case .animals: "pawprint"
        case .leisure: "figure.walk"
        case .describing: "paintpalette"
        case .other: "ellipsis.circle"
        }
    }
}

/// Words in one topic (`nil` = no topic), split by confidence.
public struct TopicBreakdown: Equatable, Sendable, Identifiable {
    public let topic: VocabularyTopic?
    public let counts: [ConfidenceCount]

    public var id: String { topic?.rawValue ?? "none" }
    public var total: Int { counts.reduce(0) { $0 + $1.count } }
    public var title: String { topic?.title ?? "No topic" }
}

extension VocabularyStatistics {
    /// Non-empty topics, largest first (ties in topic order), with words without a topic last.
    public var topicBreakdown: [TopicBreakdown] {
        let groups = Dictionary(grouping: items, by: \.topic)
        let order: (VocabularyTopic?) -> Int = { topic in
            topic.map { VocabularyTopic.allCases.firstIndex(of: $0)! } ?? Int.max
        }
        return groups
            .map { topic, words in
                TopicBreakdown(topic: topic, counts: ConfidenceLevel.allCases.map { level in
                    ConfidenceCount(level: level, count: words.filter { $0.confidence == level }.count)
                })
            }
            .sorted { a, b in
                if (a.topic == nil) != (b.topic == nil) { return b.topic == nil }
                return a.total != b.total ? a.total > b.total : order(a.topic) < order(b.topic)
            }
    }
}
