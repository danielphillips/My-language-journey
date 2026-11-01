import Foundation
import Testing
@testable import MyRussianCore

@Suite("Proficiency levels")
struct ProficiencyLevelTests {
    @Test func levelsFollowTheCEFRAlignedTORFLOrder() {
        #expect(ProficiencyLevel.allCases.map(\.code) == ["A1", "A2", "B1", "B2", "C1", "C2"])
        #expect(ProficiencyLevel.allCases.map(\.title) == [
            "Elementary", "Basic", "Intermediate", "Upper Intermediate", "Advanced", "Proficiency"
        ])
    }

    @Test func onlyA1HasADefaultHourEstimateBecauseOthersAreUnverified() {
        #expect(ProficiencyLevel.a1.defaultEstimatedHours == 110)
        for level in ProficiencyLevel.allCases where level != .a1 {
            #expect(level.defaultEstimatedHours == nil)
        }
    }
}

@Suite("Goal settings")
struct GoalSettingsTests {
    @Test func initialConfigurationMatchesThePersonalPlan() {
        let goal = GoalSettings.initial
        #expect(goal.level == .a1)
        #expect(goal.examDate == .month(year: 2027, month: 5))
        #expect(goal.weeklyTargetHours == 7)
        #expect(goal.estimatedHours == 110)
    }

    @Test func changingLevelAdoptsKnownEstimateOrKeepsTheUsersOwn() {
        var goal = GoalSettings.initial
        goal.estimatedHours = 95
        goal.changeLevel(to: .a2)
        #expect(goal.level == .a2)
        #expect(goal.estimatedHours == 95, "No verified A2 estimate exists, so the user's figure is kept")

        goal.changeLevel(to: .a1)
        #expect(goal.estimatedHours == 110)
    }

    @Test func goalSettingsRoundTripThroughCodable() throws {
        var goal = GoalSettings.initial
        goal.examDate = .day(date(2027, 5, 18))
        let data = try JSONEncoder().encode(goal)
        #expect(try JSONDecoder().decode(GoalSettings.self, from: data) == goal)
    }
}

@Suite("Exam date")
struct ExamDateTests {
    @Test func monthLevelPlanningTargetsTheStartOfTheMonth() {
        #expect(ExamDate.month(year: 2027, month: 5).targetDate(in: testCalendar) == date(2027, 5, 1))
    }

    @Test func exactDateTargetsTheStartOfThatDay() {
        #expect(ExamDate.day(date(2027, 5, 18, 14, 30)).targetDate(in: testCalendar) == date(2027, 5, 18))
    }

    @Test func monthLevelPrecisionIsReported() {
        #expect(ExamDate.month(year: 2027, month: 5).isMonthOnly)
        #expect(!ExamDate.day(date(2027, 5, 18)).isMonthOnly)
    }
}

@Suite("Goal progress")
struct GoalProgressTests {
    let goal = GoalSettings.initial // A1, May 2027, 7 h/week, 110 h

    @Test func progressAgainstTheStudyHourEstimate() {
        let progress = GoalProgress(goal: goal, totalStudied: .hours(27.5), thisWeek: .hours(3.5),
                                    recentWeeklyAverage: .hours(6), now: date(2026, 11, 2), calendar: testCalendar)
        #expect(progress.completedHours == 27.5)
        #expect(progress.estimatedHours == 110)
        #expect(progress.fractionComplete == 0.25)
        #expect(progress.remainingHours == 82.5)
        #expect(progress.thisWeekHours == 3.5)
        #expect(progress.weeklyFraction == 0.5)
    }

    @Test func fractionIsClampedButExtraHoursAreStillReported() {
        let progress = GoalProgress(goal: goal, totalStudied: .hours(130), thisWeek: .hours(10),
                                    recentWeeklyAverage: .hours(7), now: date(2026, 11, 2), calendar: testCalendar)
        #expect(progress.fractionComplete == 1)
        #expect(progress.remainingHours == 0)
        #expect(progress.completedHours == 130)
        #expect(progress.weeklyFraction > 1)
        #expect(progress.pace == .estimateReached)
    }

    @Test func timeRemainingUntilTheExam() {
        let progress = GoalProgress(goal: goal, totalStudied: 0, thisWeek: 0,
                                    recentWeeklyAverage: 0, now: date(2027, 4, 3), calendar: testCalendar)
        #expect(progress.daysUntilExam == 28)
        #expect(progress.weeksUntilExam == 4)
    }

    @Test func requiredPaceSpreadsRemainingHoursOverRemainingWeeks() {
        // 40 h left, 4 weeks left → 10 h/week needed.
        let progress = GoalProgress(goal: goal, totalStudied: .hours(70), thisWeek: 0,
                                    recentWeeklyAverage: .hours(10), now: date(2027, 4, 3), calendar: testCalendar)
        #expect(progress.requiredWeeklyHours == 10)
        #expect(progress.pace == .onTrack)
        #expect(progress.weeklyTargetIsSufficient == false, "7 h/week target cannot cover 10 h/week needed")
    }

    @Test func paceIsBehindWhenRecentAverageIsBelowWhatIsRequired() {
        let progress = GoalProgress(goal: goal, totalStudied: .hours(70), thisWeek: 0,
                                    recentWeeklyAverage: .hours(9.9), now: date(2027, 4, 3), calendar: testCalendar)
        #expect(progress.pace == .behind)
    }

    @Test func examInThePastIsReportedRatherThanDividingByZero() {
        let progress = GoalProgress(goal: goal, totalStudied: .hours(70), thisWeek: 0,
                                    recentWeeklyAverage: .hours(10), now: date(2027, 5, 1), calendar: testCalendar)
        #expect(progress.daysUntilExam == 0)
        #expect(progress.requiredWeeklyHours == nil)
        #expect(progress.pace == .examDatePassed)
    }

    @Test func zeroEstimateDoesNotProduceNonsense() {
        var custom = goal
        custom.estimatedHours = 0
        let progress = GoalProgress(goal: custom, totalStudied: .hours(5), thisWeek: 0,
                                    recentWeeklyAverage: 0, now: date(2026, 11, 2), calendar: testCalendar)
        #expect(progress.fractionComplete == 0)
        #expect(progress.pace == .noEstimate)
    }
}
