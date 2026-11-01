import Foundation
import Observation
import MyRussianCore

/// App-wide dependencies, swapped for UI tests via launch arguments.
@MainActor
@Observable
final class AppEnvironment {
    @ObservationIgnored let audioStore: AudioFileStore
    let recordingFlow: RecordingFlow
    let player = AudioPlayer()
    @ObservationIgnored let isUITesting: Bool

    init(audioStore: AudioFileStore, recordingDevice: any AudioRecordingDevice, isUITesting: Bool) {
        self.audioStore = audioStore
        self.recordingFlow = RecordingFlow(device: recordingDevice, store: audioStore)
        self.isUITesting = isUITesting
    }

    struct Launch {
        let environment: AppEnvironment
        let container: ModelContainerFactory
        let timerDefaults: UserDefaults
    }

    enum ModelContainerFactory {
        case standard
        case at(URL)
    }

    /// Reads `-ui-testing` / `-reset-data` and builds the matching dependencies.
    static func launch(arguments: [String] = ProcessInfo.processInfo.arguments) throws -> Launch {
        let fileManager = FileManager.default
        let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)

        guard arguments.contains("-ui-testing") else {
            let store = try AudioFileStore(directory: support.appendingPathComponent("Recordings", isDirectory: true))
            return Launch(environment: AppEnvironment(audioStore: store, recordingDevice: AVAudioRecorderDevice(), isUITesting: false),
                          container: .standard, timerDefaults: .standard)
        }

        let root = support.appendingPathComponent("UITesting", isDirectory: true)
        let defaults = UserDefaults(suiteName: "MyRussianUITesting") ?? .standard
        if arguments.contains("-reset-data") {
            try? fileManager.removeItem(at: root)
            defaults.removePersistentDomain(forName: "MyRussianUITesting")
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try AudioFileStore(directory: root.appendingPathComponent("Recordings", isDirectory: true))
        return Launch(environment: AppEnvironment(audioStore: store, recordingDevice: SimulatedRecordingDevice(), isUITesting: true),
                      container: .at(root.appendingPathComponent("MyRussian.store")), timerDefaults: defaults)
    }
}
