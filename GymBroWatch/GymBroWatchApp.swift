import HealthKit
import SwiftUI
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        WatchHealthWorkoutManager.shared.startWorkout(configuration: workoutConfiguration)
    }

    func handleActiveWorkoutRecovery() {
        WatchHealthWorkoutManager.shared.recoverActiveWorkout()
    }
}

@main
struct GymBroWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @State private var store = WatchWorkoutStore()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(store: store)
        }
    }
}
