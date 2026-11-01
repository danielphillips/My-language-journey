import Foundation
import Testing
@testable import MyRussianCore

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("MyRussianTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite("Audio file store")
struct AudioFileStoreTests {
    let root: URL
    let store: AudioFileStore

    init() throws {
        root = try makeTemporaryDirectory()
        store = try AudioFileStore(directory: root.appendingPathComponent("Recordings"))
    }

    @Test func createsItsDirectory() {
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: store.directory.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test func newRecordingLocationsAreUniqueRelativeM4AFiles() {
        let a = store.newRecordingLocation()
        let b = store.newRecordingLocation()
        #expect(a.relativePath != b.relativePath)
        #expect(a.relativePath.hasSuffix(".m4a"))
        #expect(!a.relativePath.contains("/"))
        #expect(a.url == store.url(for: a.relativePath))
    }

    @Test func importCopiesTheFileIntoAppStorage() throws {
        let source = root.appendingPathComponent("Где.MP3")
        try Data(repeating: 7, count: 1024).write(to: source)

        let stored = try store.importAudio(from: source)
        #expect(stored.relativePath.hasSuffix(".mp3"))
        #expect(store.fileExists(stored.relativePath))
        #expect(FileManager.default.fileExists(atPath: source.path), "The original is copied, not moved")
        #expect(try Data(contentsOf: store.url(for: stored.relativePath)) == Data(repeating: 7, count: 1024))
    }

    @Test func importRejectsNonAudioFiles() throws {
        let source = root.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: source)
        #expect(throws: AudioFileStoreError.unsupportedFormat) { try store.importAudio(from: source) }
    }

    @Test func importRejectsOversizedFiles() throws {
        let small = try AudioFileStore(directory: root.appendingPathComponent("Small"), maximumImportBytes: 100)
        let source = root.appendingPathComponent("long.m4a")
        try Data(count: 101).write(to: source)
        #expect(throws: AudioFileStoreError.fileTooLarge) { try small.importAudio(from: source) }
    }

    @Test func importOfAMissingSourceFailsCleanly() {
        #expect(throws: AudioFileStoreError.sourceMissing) {
            try store.importAudio(from: root.appendingPathComponent("ghost.m4a"))
        }
    }

    @Test func deleteRemovesTheFileAndIsSafeToRepeat() throws {
        let location = store.newRecordingLocation()
        try Data([1, 2, 3]).write(to: location.url)
        try store.delete(location.relativePath)
        #expect(!store.fileExists(location.relativePath))
        try store.delete(location.relativePath)
    }

    @Test func deleteRefusesPathsOutsideItsDirectory() throws {
        let outside = root.appendingPathComponent("precious.m4a")
        try Data([1]).write(to: outside)
        #expect(throws: AudioFileStoreError.invalidPath) { try store.delete("../precious.m4a") }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test func missingFilesAreReportedNotCrashed() {
        #expect(!store.fileExists("does-not-exist.m4a"))
        #expect(!store.fileExists("../escape.m4a"))
    }

    @Test func orphanedFilesAreThoseNoRecordingReferences() throws {
        let kept = store.newRecordingLocation(), orphan = store.newRecordingLocation()
        try Data([1]).write(to: kept.url)
        try Data([1]).write(to: orphan.url)
        #expect(store.orphanedFiles(referenced: [kept.relativePath]) == [orphan.relativePath])
    }
}

/// Fake microphone: no hardware required.
final class FakeRecordingDevice: AudioRecordingDevice, @unchecked Sendable {
    var permission: MicrophonePermission = .granted
    var grantsOnRequest = true
    var failOnStart = false
    var recordedDuration: TimeInterval = 2.5
    private(set) var permissionRequests = 0
    private(set) var recordingURL: URL?
    private(set) var cancelled = false

    var currentPermission: MicrophonePermission { permission }

    func requestPermission() async -> Bool {
        permissionRequests += 1
        permission = grantsOnRequest ? .granted : .denied
        return grantsOnRequest
    }

    func startRecording(to url: URL) throws {
        if failOnStart { throw CocoaError(.fileWriteUnknown) }
        recordingURL = url
        try Data([0, 1, 2]).write(to: url) // the real recorder creates the file on start
    }

    var currentTime: TimeInterval { recordingURL == nil ? 0 : recordedDuration }

    func stopRecording() -> TimeInterval {
        defer { recordingURL = nil }
        return recordedDuration
    }

    func cancelRecording() {
        cancelled = true
        recordingURL = nil
    }
}

@MainActor
@Suite("Recording flow")
struct RecordingFlowTests {
    let store: AudioFileStore
    let device = FakeRecordingDevice()
    let now = date(2026, 11, 2, 19)

    init() throws {
        store = try AudioFileStore(directory: try makeTemporaryDirectory())
    }

    func makeFlow() -> RecordingFlow {
        let now = self.now
        return RecordingFlow(device: device, store: store, now: { now })
    }

    @Test func recordAndStopProducesPersonalRecordingMetadata() async throws {
        let flow = makeFlow()
        await flow.start()
        #expect(flow.state == .recording(startedAt: now))

        let result = try #require(flow.stop())
        #expect(result.duration == 2.5)
        #expect(result.createdAt == now)
        #expect(result.kind == .personal)
        #expect(result.source == .recorded)
        #expect(store.fileExists(result.relativePath))
        #expect(flow.state == .idle)
    }

    @Test func eachTakeGetsItsOwnFile() async throws {
        let flow = makeFlow()
        await flow.start()
        let first = try #require(flow.stop())
        await flow.start()
        let second = try #require(flow.stop())
        #expect(first.id != second.id)
        #expect(first.relativePath != second.relativePath)
    }

    @Test func undeterminedPermissionIsRequestedOnce() async {
        device.permission = .undetermined
        let flow = makeFlow()
        await flow.start()
        #expect(device.permissionRequests == 1)
        #expect(flow.state == .recording(startedAt: now))
    }

    @Test func deniedPermissionIsReportedWithoutRecording() async {
        device.permission = .undetermined
        device.grantsOnRequest = false
        let flow = makeFlow()
        await flow.start()
        #expect(flow.state == .permissionDenied)
        #expect(device.recordingURL == nil)
    }

    @Test func previouslyDeniedOrRestrictedPermissionIsNotReRequested() async {
        for permission in [MicrophonePermission.denied, .restricted] {
            device.permission = permission
            let flow = makeFlow()
            await flow.start()
            #expect(flow.state == .permissionDenied)
        }
        #expect(device.permissionRequests == 0)
    }

    @Test func recorderFailureIsReportedAndLeavesNoFile() async {
        device.failOnStart = true
        let flow = makeFlow()
        await flow.start()
        guard case .failed = flow.state else {
            Issue.record("Expected failed state, got \(flow.state)")
            return
        }
        #expect(store.orphanedFiles(referenced: []).isEmpty)
    }

    @Test func cancellingDiscardsTheTake() async {
        let flow = makeFlow()
        await flow.start()
        flow.cancel()
        #expect(device.cancelled)
        #expect(flow.state == .idle)
        #expect(store.orphanedFiles(referenced: []).isEmpty)
    }

    @Test func tooShortTakesAreDiscarded() async {
        device.recordedDuration = 0.3
        let flow = makeFlow()
        await flow.start()
        #expect(flow.stop() == nil)
        #expect(store.orphanedFiles(referenced: []).isEmpty)
    }

    @Test func interruptionKeepsAMeaningfulTake() async throws {
        let flow = makeFlow()
        await flow.start()
        let result = try #require(flow.handleInterruption())
        #expect(result.duration == 2.5)
        #expect(flow.state == .idle)
    }

    @Test func stopWhenNotRecordingDoesNothing() {
        let flow = makeFlow()
        #expect(flow.stop() == nil)
        #expect(flow.handleInterruption() == nil)
    }

    @Test func importedAudioIsMarkedAsImportedPersonalAudio() throws {
        let source = store.directory.deletingLastPathComponent().appendingPathComponent("clip-\(UUID()).wav")
        try Data(count: 64).write(to: source)
        let result = try RecordingFlow.importRecording(from: source, duration: 1.2, store: store, now: now)
        #expect(result.source == .imported)
        #expect(result.kind == .personal)
        #expect(result.duration == 1.2)
        #expect(store.fileExists(result.relativePath))
    }
}
