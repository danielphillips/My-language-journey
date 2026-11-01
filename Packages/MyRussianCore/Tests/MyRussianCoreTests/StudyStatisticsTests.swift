import Foundation
import Testing
@testable import MyRussianCore

private func session(_ start: Date, minutes: Double, _ category: StudyCategory = .other) -> StudySessionDraft {
    StudySessionDraft(start: start, duration: .minutes(minutes), category: category)
}

@Suite("Study statistics")
struct StudyStatisticsTests {
    // 2026-11-02 is a Monday.
    let monday = date(2026, 11, 2)

    @Test func cumulativeTotalSumsAllSessions() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 10, 1, 9), minutes: 30),
            session(date(2026, 11, 3, 9), minutes: 90)
        ], calendar: testCalendar)
        #expect(stats.totalDuration == .hours(2))
    }

    @Test func weeklyTotalOnlyCountsTheWeekContainingTheDate() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 11, 1, 20), minutes: 30), // Sunday, previous week
            session(date(2026, 11, 2, 8), minutes: 45),  // Monday
            session(date(2026, 11, 8, 21), minutes: 15), // Sunday, same week
            session(date(2026, 11, 9, 8), minutes: 60)   // next Monday
        ], calendar: testCalendar)
        #expect(stats.duration(inWeekContaining: date(2026, 11, 5, 12)) == .minutes(60))
    }

    @Test func sessionCrossingAWeekBoundaryIsSplitBetweenWeeks() {
        // Sunday 23:30 → Monday 00:30.
        let stats = StudyStatistics(sessions: [session(date(2026, 11, 8, 23, 30), minutes: 60)], calendar: testCalendar)
        #expect(stats.duration(inWeekContaining: date(2026, 11, 8)) == .minutes(30))
        #expect(stats.duration(inWeekContaining: date(2026, 11, 9)) == .minutes(30))
        #expect(stats.totalDuration == .minutes(60))
    }

    @Test func sessionCrossingMidnightIsSplitBetweenDays() {
        let stats = StudyStatistics(sessions: [session(date(2026, 11, 3, 23, 40), minutes: 40)], calendar: testCalendar)
        let days = stats.dailyTotals(from: date(2026, 11, 3), through: date(2026, 11, 4))
        #expect(days.map(\.duration) == [.minutes(20), .minutes(20)])
    }

    @Test func monthlyTotalSplitsAcrossMonthBoundaries() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 10, 31, 23, 30), minutes: 60),
            session(date(2026, 11, 15, 10), minutes: 30)
        ], calendar: testCalendar)
        #expect(stats.duration(inMonthContaining: date(2026, 10, 10)) == .minutes(30))
        #expect(stats.duration(inMonthContaining: date(2026, 11, 10)) == .minutes(60))
    }

    @Test func weeklySeriesIncludesEmptyWeeksOldestFirst() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 10, 20, 9), minutes: 60),
            session(date(2026, 11, 3, 9), minutes: 120)
        ], calendar: testCalendar)
        let weeks = stats.weeklyTotals(endingWith: date(2026, 11, 4), count: 3)
        #expect(weeks.map(\.start) == [date(2026, 10, 19), date(2026, 10, 26), date(2026, 11, 2)])
        #expect(weeks.map(\.duration) == [.hours(1), 0, .hours(2)])
    }

    @Test func monthlySeriesOldestFirst() {
        let stats = StudyStatistics(sessions: [session(date(2026, 9, 5, 9), minutes: 60)], calendar: testCalendar)
        let months = stats.monthlyTotals(endingWith: date(2026, 11, 4), count: 3)
        #expect(months.map(\.start) == [date(2026, 9, 1), date(2026, 10, 1), date(2026, 11, 1)])
        #expect(months.map(\.duration) == [.hours(1), 0, 0])
    }

    @Test func categoryBreakdownIsSortedLargestFirstAndOmitsUnusedCategories() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 11, 2, 9), minutes: 20, .grammar),
            session(date(2026, 11, 3, 9), minutes: 50, .duolingo),
            session(date(2026, 11, 4, 9), minutes: 15, .grammar)
        ], calendar: testCalendar)
        let breakdown = stats.categoryBreakdown()
        #expect(breakdown.map(\.category) == [.duolingo, .grammar])
        #expect(breakdown.map(\.duration) == [.minutes(50), .minutes(35)])
    }

    @Test func categoryBreakdownCanBeLimitedToAnInterval() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 10, 2, 9), minutes: 20, .grammar),
            session(date(2026, 11, 3, 9), minutes: 50, .reading)
        ], calendar: testCalendar)
        let november = DateInterval(start: date(2026, 11, 1), end: date(2026, 12, 1))
        #expect(stats.categoryBreakdown(in: november).map(\.category) == [.reading])
    }

    @Test func weeklyGoalAttainment() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 10, 26, 9), minutes: 7 * 60),
            session(date(2026, 11, 2, 9), minutes: 3 * 60)
        ], calendar: testCalendar)
        let attainment = stats.weeklyAttainment(targetHours: 7, endingWith: date(2026, 11, 4), count: 2)
        #expect(attainment.map(\.met) == [true, false])
        #expect(attainment.map(\.fraction) == [1, 3.0 / 7.0])
    }

    @Test func recentAverageDoesNotPenaliseANewLearnerForWeeksBeforeTheyStarted() {
        // Started this week with 3 h; average over weeks actually studied so far = 3 h.
        let stats = StudyStatistics(sessions: [session(date(2026, 11, 2, 9), minutes: 180)], calendar: testCalendar)
        #expect(stats.recentWeeklyAverage(endingWith: date(2026, 11, 4), weeks: 4) == .hours(3))
    }

    @Test func recentAverageUsesTheLastNWeeksForEstablishedLearners() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 9, 1, 9), minutes: 600),   // outside the window
            session(date(2026, 10, 13, 9), minutes: 240), // 4 weeks ago
            session(date(2026, 11, 3, 9), minutes: 240)   // this week
        ], calendar: testCalendar)
        #expect(stats.recentWeeklyAverage(endingWith: date(2026, 11, 4), weeks: 4) == .hours(2))
    }

    @Test func activeDaysCountsDistinctDaysWithStudy() {
        let stats = StudyStatistics(sessions: [
            session(date(2026, 11, 2, 9), minutes: 10),
            session(date(2026, 11, 2, 20), minutes: 10),
            session(date(2026, 11, 4, 9), minutes: 10)
        ], calendar: testCalendar)
        let week = DateInterval(start: monday, end: date(2026, 11, 9))
        #expect(stats.activeDays(in: week) == 2)
    }
}

@Suite("Study session validation")
struct StudySessionValidationTests {
    let now = date(2026, 11, 4, 20)

    @Test func acceptsAReasonablePastSession() throws {
        try StudySessionValidator.validate(session(date(2026, 11, 4, 9), minutes: 45), against: [], now: now)
    }

    @Test func rejectsZeroOrNegativeDurations() {
        #expect(throws: StudySessionValidationError.durationTooShort) {
            try StudySessionValidator.validate(session(date(2026, 11, 4, 9), minutes: 0), against: [], now: now)
        }
    }

    @Test func rejectsImplausiblyLongSessions() {
        #expect(throws: StudySessionValidationError.durationTooLong) {
            try StudySessionValidator.validate(session(date(2026, 11, 1, 9), minutes: 24 * 60 + 1), against: [], now: now)
        }
    }

    @Test func rejectsSessionsEndingInTheFuture() {
        #expect(throws: StudySessionValidationError.endsInFuture) {
            try StudySessionValidator.validate(session(date(2026, 11, 4, 19, 30), minutes: 60), against: [], now: now)
        }
    }

    @Test func rejectsAnExactDuplicate() {
        let existing = session(date(2026, 11, 4, 9), minutes: 45, .grammar)
        #expect(throws: StudySessionValidationError.duplicate) {
            try StudySessionValidator.validate(existing, against: [existing], now: now)
        }
    }

    @Test func rejectsOverlapBecauseItWouldDoubleCountTime() {
        let existing = session(date(2026, 11, 4, 9), minutes: 60, .grammar)
        #expect(throws: StudySessionValidationError.overlapsExistingSession) {
            try StudySessionValidator.validate(session(date(2026, 11, 4, 9, 30), minutes: 60, .reading), against: [existing], now: now)
        }
    }

    @Test func backToBackSessionsAreAllowed() throws {
        let existing = session(date(2026, 11, 4, 9), minutes: 60, .grammar)
        try StudySessionValidator.validate(session(date(2026, 11, 4, 10), minutes: 30, .reading), against: [existing], now: now)
    }
}
