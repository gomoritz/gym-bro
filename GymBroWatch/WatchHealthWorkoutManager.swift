import Foundation
import HealthKit

@MainActor
@Observable
final class WatchHealthWorkoutManager: NSObject {
    static let shared = WatchHealthWorkoutManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var isRunning = false
    private(set) var errorMessage: String?

    func startWorkout(configuration: HKWorkoutConfiguration) {
        guard !isRunning, session == nil else { return }

        Task {
            do {
                try await authorizeHealthKit()
                try beginWorkout(configuration: configuration)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func recoverActiveWorkout() {
        healthStore.recoverActiveWorkoutSession { session, error in
            Task { @MainActor in
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let session else { return }
                self.session = session
                self.builder = session.associatedWorkoutBuilder()
                self.session?.delegate = self
                self.builder?.delegate = self
                self.isRunning = session.state == .running
            }
        }
    }

    func endWorkout() {
        guard let session, let builder else { return }
        let endDate = Date()
        session.end()
        builder.endCollection(withEnd: endDate) { success, error in
            guard success else {
                Task { @MainActor in self.errorMessage = error?.localizedDescription }
                return
            }
            builder.finishWorkout { _, error in
                Task { @MainActor in
                    self.errorMessage = error?.localizedDescription
                    self.session = nil
                    self.builder = nil
                    self.isRunning = false
                }
            }
        }
    }

    private func authorizeHealthKit() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let workout = HKObjectType.workoutType()
        var readTypes: Set<HKObjectType> = []
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergy)
        }
        try await healthStore.requestAuthorization(toShare: [workout], read: readTypes)
    }

    private func beginWorkout(configuration: HKWorkoutConfiguration) throws {
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        session.delegate = self
        builder.delegate = self

        self.session = session
        self.builder = builder

        let startDate = Date()
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { success, error in
            Task { @MainActor in
                self.isRunning = success
                self.errorMessage = error?.localizedDescription
            }
        }
    }
}

extension WatchHealthWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in self.isRunning = toState == .running }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.isRunning = false
        }
    }
}

extension WatchHealthWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {}
}
