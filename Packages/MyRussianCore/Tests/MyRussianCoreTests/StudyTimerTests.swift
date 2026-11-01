import Foundation
import Testing
@testable import MyRussianCore

@Suite("Study categories")
struct StudyCategoryTests {
    @Test func suggestedCategoriesInDisplayOrder() {
        #expect(StudyCategory.allCases.map(\.title) == [
            "Duolingo", "Vocabulary", "Grammar", "Listening", "Speaking", "Reading", "Writing", "Tutoring", "Other"
        ])
    }

    @Test func everyCategoryHasASymbol() {
        for category in StudyCategory.allCases {
            #expect(!category.systemImage.isEmpty)
        }
    }
}

@Suite("Study timer")
struct StudyTimerTests {
    let t0 = date(2026, 11, 2, 18, 0)

    @Test func newTimerIsIdleWithNoElapsedTime() {
        let timer = StudyTimer()
        #expect(timer.state == .idle)
        #expect(timer.elapsed(at: t0) == 0)
        #expect(!timer.isActive)
    }

    @Test func runningTimerMeasuresWallClockTime() {
        var timer = StudyTimer()
        timer.start(at: t0)
        #expect(timer.state == .running(since: t0))
        #expect(timer.elapsed(at: t0 + .minutes(25)) == .minutes(25))
    }

    @Test func pausedTimeIsNotCounted() {
        var timer = StudyTimer()
        timer.start(at: t0)
        timer.pause(at: t0 + .minutes(10))
        #expect(timer.elapsed(at: t0 + .minutes(40)) == .minutes(10))
        timer.resume(at: t0 + .minutes(40))
        #expect(timer.elapsed(at: t0 + .minutes(45)) == .minutes(15))
    }

    @Test func repeatedPauseOrResumeDoesNotDoubleCount() {
        var timer = StudyTimer()
        timer.start(at: t0)
        timer.pause(at: t0 + .minutes(10))
        timer.pause(at: t0 + .minutes(20))
        timer.resume(at: t0 + .minutes(30))
        timer.resume(at: t0 + .minutes(35))
        timer.start(at: t0 + .minutes(36))
        #expect(timer.elapsed(at: t0 + .minutes(40)) == .minutes(20))
    }

    @Test func stopReturnsTheCompletedSessionAndResets() throws {
        var timer = StudyTimer(category: .listening)
        timer.notes = "Podcast episode 4"
        timer.start(at: t0)
        timer.pause(at: t0 + .minutes(20))
        timer.resume(at: t0 + .minutes(30))
        let stopped = timer.stop(at: t0 + .minutes(50))
        let session = try #require(stopped)
        #expect(session.start == t0)
        #expect(session.duration == .minutes(40))
        #expect(session.category == .listening)
        #expect(session.notes == "Podcast episode 4")
        #expect(timer.state == .idle)
        #expect(timer.elapsed(at: t0 + .hours(2)) == 0)
    }

    @Test func stoppingWithoutMeaningfulTimeYieldsNothing() {
        var timer = StudyTimer()
        let early = timer.stop(at: t0)
        #expect(early == nil)
        timer.start(at: t0)
        let tooShort = timer.stop(at: t0 + 0.5)
        #expect(tooShort == nil)
    }

    @Test func discardResetsWithoutProducingASession() {
        var timer = StudyTimer(category: .grammar)
        timer.start(at: t0)
        timer.discard()
        #expect(timer.state == .idle)
        let afterDiscard = timer.stop(at: t0 + .minutes(30))
        #expect(afterDiscard == nil)
    }

    @Test func survivesBackgroundingAndTerminationViaPersistedState() throws {
        var timer = StudyTimer(category: .reading)
        timer.start(at: t0)
        timer.pause(at: t0 + .minutes(15))
        timer.resume(at: t0 + .minutes(20))

        // App is backgrounded and terminated; state is persisted and restored later.
        let data = try JSONEncoder().encode(timer)
        var restored = try JSONDecoder().decode(StudyTimer.self, from: data)
        #expect(restored.elapsed(at: t0 + .minutes(80)) == .minutes(75))
        let stopped = restored.stop(at: t0 + .minutes(80))
        let session = try #require(stopped)
        #expect(session.duration == .minutes(75))
        #expect(session.category == .reading)
    }

    @Test func clockGoingBackwardsNeverProducesNegativeTime() {
        var timer = StudyTimer()
        timer.start(at: t0)
        #expect(timer.elapsed(at: t0 - .minutes(5)) == 0)
        timer.pause(at: t0 - .minutes(5))
        #expect(timer.elapsed(at: t0 + .minutes(5)) == 0)
    }

    @Test func categoryCanChangeWhileRunning() throws {
        var timer = StudyTimer(category: .other)
        timer.start(at: t0)
        timer.category = .speaking
        let stopped = timer.stop(at: t0 + .minutes(5))
        let session = try #require(stopped)
        #expect(session.category == .speaking)
    }
}
