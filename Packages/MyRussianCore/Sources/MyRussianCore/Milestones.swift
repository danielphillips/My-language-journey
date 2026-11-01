import Foundation

public enum Competency: String, CaseIterable, Codable, Sendable, Identifiable {
    case alphabet, vocabulary, grammar, speaking, listening, reading, writing

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .alphabet: "Cyrillic & Pronunciation"
        case .vocabulary: "Vocabulary"
        case .grammar: "Grammar"
        case .speaking: "Speaking"
        case .listening: "Listening"
        case .reading: "Reading"
        case .writing: "Writing"
        }
    }

    public var systemImage: String {
        switch self {
        case .alphabet: "character"
        case .vocabulary: "character.book.closed"
        case .grammar: "textformat.abc"
        case .speaking: "waveform"
        case .listening: "headphones"
        case .reading: "book"
        case .writing: "pencil.line"
        }
    }

    /// The TORFL subtest this competency prepares for. TORFL has five subtests:
    /// Vocabulary & Grammar, Reading, Listening, Writing and Speaking (SPbU Testing Centre).
    /// The alphabet is foundational and has no subtest of its own.
    public var torflSubtest: String? {
        switch self {
        case .alphabet: nil
        case .vocabulary, .grammar: "Vocabulary & Grammar"
        case .speaking: "Speaking"
        case .listening: "Listening"
        case .reading: "Reading"
        case .writing: "Writing"
        }
    }
}

public enum MilestoneStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    case notStarted, learning, comfortable, demonstrated

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .notStarted: "Not Started"
        case .learning: "Learning"
        case .comfortable: "Comfortable"
        case .demonstrated: "Demonstrated"
        }
    }

    public var systemImage: String {
        switch self {
        case .notStarted: "circle"
        case .learning: "circle.lefthalf.filled"
        case .comfortable: "circle.fill"
        case .demonstrated: "checkmark.seal.fill"
        }
    }

    public var isSecured: Bool { self == .comfortable || self == .demonstrated }

    public var next: MilestoneStatus {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

public enum MilestoneBasis: Equatable, Sendable {
    /// Written for this app as a practical learning objective; not an official syllabus item.
    case appAuthored
}

public struct Milestone: Identifiable, Hashable, Sendable {
    public let id: String
    public let level: ProficiencyLevel
    public let competency: Competency
    public let title: String
    public let detail: String
    public let basis: MilestoneBasis
}

public enum MilestoneCatalog {
    public static func milestones(for level: ProficiencyLevel) -> [Milestone] {
        level == .a1 ? a1 : []
    }

    private static func make(_ competency: Competency, _ items: [(String, String, String)]) -> [Milestone] {
        items.map { key, title, detail in
            Milestone(id: "a1.\(competency.rawValue).\(key)", level: .a1, competency: competency,
                      title: title, detail: detail, basis: .appAuthored)
        }
    }

    static let a1: [Milestone] =
        make(.alphabet, [
            ("letters", "Recognise all 33 Cyrillic letters", "Including the look‑alikes: В, Н, Р, С, У, Х."),
            ("handwriting", "Write every letter by hand", "Printed and cursive forms."),
            ("signs", "Understand hard and soft signs", "What ъ and ь do to the sounds around them."),
            ("simple-words", "Read simple Russian words", "Sound out short words without transliteration."),
            ("stress", "Hear and mark word stress", "Stress changes vowel sounds and sometimes meaning."),
            ("reduction", "Recognise basic pronunciation patterns", "Unstressed о sounds like а; final consonants devoice.")
        ])
        + make(.vocabulary, [
            ("greetings", "Greetings and polite expressions", "Здравствуйте, привет, спасибо, пожалуйста, извините."),
            ("numbers", "Numbers, prices and quantities", "Count to 1000; understand prices."),
            ("time", "Days, months and telling the time", "Ask and say what time or day something happens."),
            ("people", "Family, people and professions", "Talk about who people are and what they do."),
            ("food", "Food, drink and shopping", "Order, buy and ask for what you need."),
            ("city", "City, transport and directions", "Places, getting around, left/right/straight on."),
            ("routine", "Daily routine, work and study", "Describe a normal day.")
        ])
        + make(.grammar, [
            ("gender", "Understand grammatical gender", "Masculine, feminine and neuter by word ending."),
            ("pronouns", "Use basic personal pronouns", "я, ты, он, она, мы, вы, они."),
            ("present", "Form simple present‑tense sentences", "First and second conjugation verbs."),
            ("past", "Use the past tense", "Gender and number agreement: читал, читала, читали."),
            ("plurals", "Form noun plurals", "Including common spelling rules."),
            ("cases", "Recognise basic case usage", "Accusative for objects, prepositional for location (в/на)."),
            ("possessives", "Use possessives", "мой, твой, наш, ваш and agreement."),
            ("questions", "Form common questions", "кто, что, где, когда, как, сколько, почему.")
        ])
        + make(.speaking, [
            ("introduce", "Introduce yourself", "Name, nationality, languages, where you live."),
            ("personal", "Ask and answer personal questions", "Short exchanges about family, work and interests."),
            ("shopping", "Buy something and ask the price", "Handle a simple transaction."),
            ("directions", "Ask for and follow directions", "Ask where something is and understand the answer."),
            ("day", "Talk about your day", "Describe what you did and plan to do.")
        ])
        + make(.listening, [
            ("numbers", "Catch numbers, prices and times", "In slow, clear speech."),
            ("dialogues", "Follow short everyday dialogues", "Identify who, what, where and when."),
            ("announcements", "Pick out key information from announcements", "Stations, times, platforms."),
            ("questions", "Understand questions addressed to you", "Respond appropriately without translation.")
        ])
        + make(.reading, [
            ("signs", "Read signs, menus and timetables", "Find what you need in everyday texts."),
            ("short-texts", "Read short texts on familiar topics", "Personal letters, simple descriptions."),
            ("scan", "Find specific information in a text", "Scan for names, times, numbers and places.")
        ])
        + make(.writing, [
            ("form", "Fill in a form with personal details", "Name, address, date of birth, nationality."),
            ("note", "Write a short note or message", "Invitations, thanks, arrangements."),
            ("about-me", "Write a short paragraph about yourself", "Connected sentences about your life.")
        ])
}

public struct CompetencyProgress: Identifiable, Sendable {
    public let competency: Competency
    public let milestones: [Milestone]
    private let counts: [MilestoneStatus: Int]

    public var id: Competency { competency }
    public var total: Int { milestones.count }

    init(competency: Competency, milestones: [Milestone], statuses: [String: MilestoneStatus]) {
        self.competency = competency
        self.milestones = milestones
        var counts: [MilestoneStatus: Int] = [:]
        for milestone in milestones { counts[statuses[milestone.id] ?? .notStarted, default: 0] += 1 }
        self.counts = counts
    }

    public func count(of status: MilestoneStatus) -> Int { counts[status] ?? 0 }

    public var securedFraction: Double {
        total == 0 ? 0 : Double(count(of: .comfortable) + count(of: .demonstrated)) / Double(total)
    }
}

/// Progress through a roadmap given the user's milestone statuses (keyed by milestone ID).
public struct RoadmapProgress: Sendable {
    public let milestones: [Milestone]
    public let competencies: [CompetencyProgress]
    private let statuses: [String: MilestoneStatus]

    public init(milestones: [Milestone], statuses: [String: MilestoneStatus]) {
        self.milestones = milestones
        self.statuses = statuses
        competencies = Competency.allCases.compactMap { competency in
            let items = milestones.filter { $0.competency == competency }
            return items.isEmpty ? nil : CompetencyProgress(competency: competency, milestones: items, statuses: statuses)
        }
    }

    public func status(of milestone: Milestone) -> MilestoneStatus {
        statuses[milestone.id] ?? .notStarted
    }

    public func count(of status: MilestoneStatus) -> Int {
        milestones.filter { self.status(of: $0) == status }.count
    }

    public var securedFraction: Double {
        milestones.isEmpty ? 0 : Double(milestones.count - remainingCount) / Double(milestones.count)
    }

    public var remainingCount: Int {
        milestones.filter { !status(of: $0).isSecured }.count
    }

    /// In-progress milestones first, then not-started ones, each in roadmap order.
    public func upNext(limit: Int) -> [Milestone] {
        let learning = milestones.filter { status(of: $0) == .learning }
        let notStarted = milestones.filter { status(of: $0) == .notStarted }
        return Array((learning + notStarted).prefix(limit))
    }
}
