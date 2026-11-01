import Foundation

public struct PeriodTotal: Equatable, Sendable, Identifiable {
    public let start: Date
    public let duration: TimeInterval
    public var id: Date { start }
    public var hours: Double { duration / 3600 }
}

public struct CategoryTotal: Equatable, Sendable, Identifiable {
    public let category: StudyCategory
    public let duration: TimeInterval
    public var id: StudyCategory { category }
    public var hours: Double { duration / 3600 }
}

public struct WeekAttainment: Equatable, Sendable, Identifiable {
    public let weekStart: Date
    public let duration: TimeInterval
    public let fraction: Double
    public let met: Bool
    public var id: Date { weekStart }
}

/// Aggregates study sessions. Sessions spanning a day, week or month boundary are split
/// proportionally, so every second is counted in exactly one period.
public struct StudyStatistics: Sendable {
    private let sessions: [StudySessionDraft]
    private let calendar: Calendar

    public init(sessions: [StudySessionDraft], calendar: Calendar) {
        self.sessions = sessions.filter { $0.duration > 0 }
        self.calendar = calendar
    }

    public var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    public func duration(in interval: DateInterval) -> TimeInterval {
        sessions.reduce(0) { $0 + Self.overlap($1, interval) }
    }

    public func duration(inWeekContaining date: Date) -> TimeInterval {
        duration(in: period(.weekOfYear, containing: date))
    }

    public func duration(inMonthContaining date: Date) -> TimeInterval {
        duration(in: period(.month, containing: date))
    }

    public func dailyTotals(from first: Date, through last: Date) -> [PeriodTotal] {
        var totals: [PeriodTotal] = []
        var day = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: last)
        while day <= end {
            let interval = period(.day, containing: day)
            totals.append(PeriodTotal(start: interval.start, duration: duration(in: interval)))
            day = interval.end
        }
        return totals
    }

    public func weeklyTotals(endingWith date: Date, count: Int) -> [PeriodTotal] {
        series(.weekOfYear, endingWith: date, count: count)
    }

    public func monthlyTotals(endingWith date: Date, count: Int) -> [PeriodTotal] {
        series(.month, endingWith: date, count: count)
    }

    public func categoryBreakdown(in interval: DateInterval? = nil) -> [CategoryTotal] {
        var totals: [StudyCategory: TimeInterval] = [:]
        for session in sessions {
            let value = interval.map { Self.overlap(session, $0) } ?? session.duration
            if value > 0 { totals[session.category, default: 0] += value }
        }
        return totals
            .map { CategoryTotal(category: $0.key, duration: $0.value) }
            .sorted {
                $0.duration != $1.duration
                    ? $0.duration > $1.duration
                    : StudyCategory.allCases.firstIndex(of: $0.category)! < StudyCategory.allCases.firstIndex(of: $1.category)!
            }
    }

    public func weeklyAttainment(targetHours: Double, endingWith date: Date, count: Int) -> [WeekAttainment] {
        weeklyTotals(endingWith: date, count: count).map { week in
            let fraction = targetHours > 0 ? week.hours / targetHours : 0
            return WeekAttainment(weekStart: week.start, duration: week.duration, fraction: fraction, met: targetHours > 0 && fraction >= 1)
        }
    }

    /// Average weekly study time over the last `weeks` weeks (including the current one),
    /// counting only weeks since the learner's first session.
    public func recentWeeklyAverage(endingWith date: Date, weeks: Int) -> TimeInterval {
        guard weeks > 0, let first = sessions.map(\.start).min() else { return 0 }
        let firstWeek = period(.weekOfYear, containing: first).start
        let currentWeek = period(.weekOfYear, containing: date).start
        let weeksSinceStart = (calendar.dateComponents([.weekOfYear], from: firstWeek, to: currentWeek).weekOfYear ?? 0) + 1
        let considered = max(1, min(weeks, weeksSinceStart))
        let total = weeklyTotals(endingWith: date, count: considered).reduce(0) { $0 + $1.duration }
        return total / Double(considered)
    }

    public func activeDays(in interval: DateInterval) -> Int {
        let lastInstant = interval.end.addingTimeInterval(-1)
        guard lastInstant >= interval.start else { return 0 }
        return dailyTotals(from: interval.start, through: lastInstant).filter { $0.duration > 0 }.count
    }

    // MARK: - Helpers

    private func period(_ component: Calendar.Component, containing date: Date) -> DateInterval {
        calendar.dateInterval(of: component, for: date)!
    }

    private func series(_ component: Calendar.Component, endingWith date: Date, count: Int) -> [PeriodTotal] {
        guard count > 0 else { return [] }
        let current = period(component, containing: date).start
        return (0..<count).reversed().map { offset in
            let start = calendar.date(byAdding: component, value: -offset, to: current)!
            return PeriodTotal(start: start, duration: duration(in: period(component, containing: start)))
        }
    }

    static func overlap(_ session: StudySessionDraft, _ interval: DateInterval) -> TimeInterval {
        let start = max(session.start, interval.start)
        let end = min(session.end, interval.end)
        return max(end.timeIntervalSince(start), 0)
    }
}

public enum StudySessionValidationError: Error, Equatable, Sendable {
    case durationTooShort
    case durationTooLong
    case endsInFuture
    case duplicate
    case overlapsExistingSession

    public var message: String {
        switch self {
        case .durationTooShort: "Add some study time first."
        case .durationTooLong: "A single session can’t be longer than 24 hours."
        case .endsInFuture: "This session would end in the future."
        case .duplicate: "This session has already been logged."
        case .overlapsExistingSession: "This overlaps a session you’ve already logged."
        }
    }
}

public enum StudySessionValidator {
    public static let maximumDuration: TimeInterval = 24 * 3600
    static let tolerance: TimeInterval = 60

    /// Validates a new or edited session against the other recorded sessions
    /// (when editing, pass every session except the one being edited).
    public static func validate(_ draft: StudySessionDraft, against others: [StudySessionDraft], now: Date) throws {
        guard draft.duration >= StudyTimer.minimumDuration else { throw StudySessionValidationError.durationTooShort }
        guard draft.duration <= maximumDuration else { throw StudySessionValidationError.durationTooLong }
        guard draft.end <= now + tolerance else { throw StudySessionValidationError.endsInFuture }

        if others.contains(where: { isDuplicate(draft, $0) }) {
            throw StudySessionValidationError.duplicate
        }
        let interval = DateInterval(start: draft.start, duration: draft.duration)
        if others.contains(where: { StudyStatistics.overlap($0, interval) > 0 }) {
            throw StudySessionValidationError.overlapsExistingSession
        }
    }

    private static func isDuplicate(_ a: StudySessionDraft, _ b: StudySessionDraft) -> Bool {
        a.category == b.category
            && abs(a.start.timeIntervalSince(b.start)) < tolerance
            && abs(a.duration - b.duration) < tolerance
    }
}
