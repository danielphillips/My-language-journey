import Foundation

/// TORFL levels, aligned with CEFR.
public enum ProficiencyLevel: String, CaseIterable, Codable, Sendable, Identifiable {
    case a1, a2, b1, b2, c1, c2

    public var id: String { rawValue }

    public var code: String { rawValue.uppercased() }

    public var title: String {
        switch self {
        case .a1: "Elementary"
        case .a2: "Basic"
        case .b1: "Intermediate"
        case .b2: "Upper Intermediate"
        case .c1: "Advanced"
        case .c2: "Proficiency"
        }
    }

    /// Russian name of the TORFL (ТРКИ) exam at this level.
    public var torflName: String {
        switch self {
        case .a1: "ТЭУ"
        case .a2: "ТБУ"
        case .b1: "ТРКИ‑1"
        case .b2: "ТРКИ‑2"
        case .c1: "ТРКИ‑3"
        case .c2: "ТРКИ‑4"
        }
    }

    /// Indicative cumulative study hours. Only A1 has a value (the learner's own planning figure);
    /// no authoritative figures are invented for other levels.
    public var defaultEstimatedHours: Double? {
        self == .a1 ? 110 : nil
    }

    /// Widely cited size of the TORFL Elementary (A1) lexical minimum. A contextual reference only:
    /// personal entries are never checked against the official list. Other levels are left unset.
    public var lexicalMinimumReference: Int? {
        self == .a1 ? 780 : nil
    }
}

/// An exam date planned to month precision, or an exact day once known.
public enum ExamDate: Codable, Hashable, Sendable {
    case month(year: Int, month: Int)
    case day(Date)

    public var isMonthOnly: Bool {
        if case .month = self { true } else { false }
    }

    /// The date used for planning. Month-level plans conservatively target the first day of the month.
    public func targetDate(in calendar: Calendar) -> Date {
        switch self {
        case let .month(year, month):
            calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        case let .day(date):
            calendar.startOfDay(for: date)
        }
    }
}

public struct GoalSettings: Codable, Hashable, Sendable {
    public var level: ProficiencyLevel
    public var examDate: ExamDate
    public var weeklyTargetHours: Double
    public var estimatedHours: Double

    public init(level: ProficiencyLevel, examDate: ExamDate, weeklyTargetHours: Double, estimatedHours: Double) {
        self.level = level
        self.examDate = examDate
        self.weeklyTargetHours = weeklyTargetHours
        self.estimatedHours = estimatedHours
    }

    public static let initial = GoalSettings(
        level: .a1,
        examDate: .month(year: 2027, month: 5),
        weeklyTargetHours: 7,
        estimatedHours: 110
    )

    /// Changes the target level, adopting a known estimate when one exists and otherwise keeping the user's figure.
    public mutating func changeLevel(to newLevel: ProficiencyLevel) {
        level = newLevel
        if let known = newLevel.defaultEstimatedHours {
            estimatedHours = known
        }
    }
}

public enum PaceStatus: Equatable, Sendable {
    case onTrack
    case behind
    case estimateReached
    case examDatePassed
    case noEstimate
}

/// Effort-based progress towards the goal. Hours measure effort, never proficiency.
public struct GoalProgress: Equatable, Sendable {
    public let completedHours: Double
    public let estimatedHours: Double
    public let fractionComplete: Double
    public let remainingHours: Double
    public let thisWeekHours: Double
    public let weeklyTargetHours: Double
    public let weeklyFraction: Double
    public let recentWeeklyAverageHours: Double
    public let daysUntilExam: Int
    public let weeksUntilExam: Double
    public let requiredWeeklyHours: Double?
    public let pace: PaceStatus

    public var weeklyTargetIsSufficient: Bool {
        guard let required = requiredWeeklyHours else { return true }
        return weeklyTargetHours >= required
    }

    public init(
        goal: GoalSettings,
        totalStudied: TimeInterval,
        thisWeek: TimeInterval,
        recentWeeklyAverage: TimeInterval,
        now: Date,
        calendar: Calendar
    ) {
        completedHours = totalStudied / 3600
        estimatedHours = max(goal.estimatedHours, 0)
        thisWeekHours = thisWeek / 3600
        weeklyTargetHours = goal.weeklyTargetHours
        recentWeeklyAverageHours = recentWeeklyAverage / 3600

        remainingHours = max(estimatedHours - completedHours, 0)
        fractionComplete = estimatedHours > 0 ? min(completedHours / estimatedHours, 1) : 0
        weeklyFraction = weeklyTargetHours > 0 ? thisWeekHours / weeklyTargetHours : 0

        let today = calendar.startOfDay(for: now)
        let exam = goal.examDate.targetDate(in: calendar)
        let days = calendar.dateComponents([.day], from: today, to: exam).day ?? 0
        daysUntilExam = max(days, 0)
        weeksUntilExam = Double(daysUntilExam) / 7

        if estimatedHours <= 0 {
            requiredWeeklyHours = nil
            pace = .noEstimate
        } else if remainingHours == 0 {
            requiredWeeklyHours = nil
            pace = .estimateReached
        } else if daysUntilExam == 0 {
            requiredWeeklyHours = nil
            pace = .examDatePassed
        } else {
            let required = remainingHours / weeksUntilExam
            requiredWeeklyHours = required
            pace = recentWeeklyAverageHours >= required ? .onTrack : .behind
        }
    }
}
