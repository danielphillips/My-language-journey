import Foundation
import Testing
import MyRussianCore
@testable import MyRussian

@MainActor
@Suite("Live timer persistence")
struct LiveTimerStoreTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_793_000_000) }

    func makeDefaults() -> UserDefaults {
        let name = "LiveTimerStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func runningTimerSurvivesTermination() throws {
        let defaults = makeDefaults()
        let clock = Clock()
        let store = LiveTimerStore(defaults: defaults, now: { clock.now })
        store.start(category: .listening)
        clock.now += 600

        // Relaunch: a fresh store reads the persisted state.
        let relaunched = LiveTimerStore(defaults: defaults, now: { clock.now })
        #expect(relaunched.timer.isActive)
        #expect(relaunched.elapsed == 600)
        clock.now += 300
        let session = try #require(relaunched.stop())
        #expect(session.duration == 900)
        #expect(session.category == .listening)
        #expect(!LiveTimerStore(defaults: defaults, now: { clock.now }).timer.isActive)
    }

    @Test func pauseAndDiscardArePersisted() {
        let defaults = makeDefaults()
        let clock = Clock()
        let store = LiveTimerStore(defaults: defaults, now: { clock.now })
        store.start(category: .grammar)
        clock.now += 120
        store.pause()
        clock.now += 3600
        #expect(LiveTimerStore(defaults: defaults, now: { clock.now }).elapsed == 120)
        store.discard()
        #expect(!LiveTimerStore(defaults: defaults, now: { clock.now }).timer.isActive)
    }
}
