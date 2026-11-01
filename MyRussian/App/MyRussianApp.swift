import SwiftData
import SwiftUI

@main
struct MyRussianApp: App {
    @State private var environment: AppEnvironment
    @State private var timerStore: LiveTimerStore
    private let container: ModelContainer

    init() {
        do {
            let launch = try AppEnvironment.launch()
            switch launch.container {
            case .standard: container = try AppModelContainer.make()
            case let .at(url): container = try AppModelContainer.make(url: url)
            }
            _environment = State(initialValue: launch.environment)
            _timerStore = State(initialValue: LiveTimerStore(defaults: launch.timerDefaults))
        } catch {
            fatalError("My Russian couldn’t open its data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(timerStore)
        }
        .modelContainer(container)
    }
}
