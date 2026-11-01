import Foundation
import Observation
import MyRussianCore

/// Owns the live study timer and persists it after every change, so a running or paused
/// session survives backgrounding, termination and relaunch without double-counting.
@MainActor
@Observable
final class LiveTimerStore {
    static let storageKey = "liveStudyTimer.v1"

    private(set) var timer: StudyTimer
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.storageKey),
           let restored = try? JSONDecoder().decode(StudyTimer.self, from: data) {
            timer = restored
        } else {
            timer = StudyTimer()
        }
    }

    var elapsed: TimeInterval { timer.elapsed(at: now()) }

    func elapsed(at date: Date) -> TimeInterval { timer.elapsed(at: date) }

    var isRunning: Bool {
        if case .running = timer.state { true } else { false }
    }

    func start(category: StudyCategory) {
        guard !timer.isActive else { return }
        timer.category = category
        timer.start(at: now())
        persist()
    }

    func pause() {
        timer.pause(at: now())
        persist()
    }

    func resume() {
        timer.resume(at: now())
        persist()
    }

    func setCategory(_ category: StudyCategory) {
        timer.category = category
        persist()
    }

    func setNotes(_ notes: String) {
        timer.notes = notes
        persist()
    }

    /// Stops and returns the session to save. The timer resets either way.
    func stop() -> StudySessionDraft? {
        let session = timer.stop(at: now())
        persist()
        return session
    }

    func discard() {
        timer.discard()
        persist()
    }

    private func persist() {
        if timer.isActive, let data = try? JSONEncoder().encode(timer) {
            defaults.set(data, forKey: Self.storageKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }
}
