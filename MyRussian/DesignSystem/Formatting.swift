import Foundation
import MyRussianCore

enum DurationFormat {
    /// "0m", "30m", "1h 15m", "12h".
    static func short(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((max(interval, 0) / 60).rounded())
        let hours = totalMinutes / 60, minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _): return "\(minutes)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(minutes)m"
        }
    }

    /// "27.5 h".
    static func hours(_ hours: Double) -> String {
        "\(hours.formatted(.number.precision(.fractionLength(0...1)))) h"
    }

    /// "4:05" or "1:02:03" for live timers and recordings.
    static func clock(_ interval: TimeInterval) -> String {
        let seconds = Int(max(interval, 0))
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

extension ExamDate {
    func formatted(calendar: Calendar = .current) -> String {
        let date = targetDate(in: calendar)
        return isMonthOnly
            ? date.formatted(.dateTime.month(.wide).year())
            : date.formatted(.dateTime.day().month(.wide).year())
    }
}

extension ProficiencyLevel {
    var displayName: String { "\(code) · \(title)" }
}
