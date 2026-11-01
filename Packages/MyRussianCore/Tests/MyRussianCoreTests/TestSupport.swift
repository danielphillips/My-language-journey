import Foundation

/// Deterministic calendar for tests: Gregorian, UTC, weeks start on Monday.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}()

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
    testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

extension TimeInterval {
    static func hours(_ value: Double) -> TimeInterval { value * 3600 }
    static func minutes(_ value: Double) -> TimeInterval { value * 60 }
}
