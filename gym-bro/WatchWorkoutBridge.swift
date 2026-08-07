import Foundation
import HealthKit
import WatchConnectivity

@MainActor
@Observable
final class WatchWorkoutBridge: NSObject {
    static let shared = WatchWorkoutBridge()

    private let healthStore = HKHealthStore()
    private weak var sessionManager: SessionManager?
    private var revision = 0

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func connect(to sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        publishCurrentState()
    }

    func startCompanionWorkout() {
        publishCurrentState()

        guard HKHealthStore.isHealthDataAvailable() else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        healthStore.startWatchApp(with: configuration) { success, error in
            if !success, let error {
                print("Unable to start workout on Apple Watch: \(error.localizedDescription)")
            }
        }
    }

    func publishCurrentState() {
        revision += 1
        let snapshot = makeSnapshot()
        guard let data = try? WatchWorkoutMessage.encode(snapshot), WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else { return }

        do {
            try session.updateApplicationContext([WatchWorkoutMessage.snapshotKey: data])
        } catch {
            print("Unable to update Watch workout context: \(error.localizedDescription)")
        }

        if session.isReachable {
            session.sendMessage(
                [WatchWorkoutMessage.snapshotKey: data],
                replyHandler: nil,
                errorHandler: { error in
                    print("Unable to send live Watch workout update: \(error.localizedDescription)")
                }
            )
        }
    }

    private func makeSnapshot() -> WatchWorkoutSnapshot {
        guard let manager = sessionManager,
              let session = manager.activeSession,
              let currentExercise = manager.currentExercise else {
            return WatchWorkoutSnapshot(
                revision: revision,
                sessionID: nil,
                splitName: nil,
                currentExercise: nil,
                remainingExercises: [],
                currentSetNumber: 1,
                suggestedWeight: nil,
                suggestedReps: nil,
                timerKind: nil,
                timerEndDate: nil,
                timerDuration: nil,
                timerExpired: false,
                isWorkoutActive: false
            )
        }

        let lastSet = manager.lastSetForCurrentExercise
        let timerKind: WatchTimerKind? = manager.isRestTimerActive || manager.isTimerExpired
            ? (manager.transitionToExercise == nil ? .rest : .transition)
            : nil

        return WatchWorkoutSnapshot(
            revision: revision,
            sessionID: session.id,
            splitName: manager.currentSplit?.name,
            currentExercise: snapshot(for: currentExercise, manager: manager),
            remainingExercises: manager.remainingExercisesInSplit.map { snapshot(for: $0, manager: manager) },
            currentSetNumber: manager.currentSetNumber,
            suggestedWeight: lastSet?.weight ?? currentExercise.effectiveTargetWeight(for: manager.currentLocation),
            suggestedReps: lastSet?.reps ?? currentExercise.minReps,
            timerKind: timerKind,
            timerEndDate: manager.timerEndDate,
            timerDuration: timerKind == nil ? nil : manager.restTimerDuration,
            timerExpired: manager.isTimerExpired,
            isWorkoutActive: true
        )
    }

    private func snapshot(for exercise: Exercise, manager: SessionManager) -> WatchExerciseSnapshot {
        WatchExerciseSnapshot(
            id: exercise.id,
            name: exercise.name,
            targetWeight: exercise.effectiveTargetWeight(for: manager.currentLocation),
            targetSets: exercise.targetSets,
            minReps: exercise.minReps,
            maxReps: exercise.maxReps,
            notes: exercise.effectiveNotes(for: manager.currentLocation)
        )
    }

    private func handle(_ command: WatchWorkoutCommand) {
        guard let manager = sessionManager else { return }

        switch command {
        case let .logSet(weight, reps):
            manager.completeSet(weight: weight, reps: reps)
        case let .selectExercise(id):
            guard let exercise = manager.remainingExercisesInSplit.first(where: { $0.id == id }) else { return }
            manager.selectNextExercise(exercise)
        case .stopTimer:
            manager.stopTimerFromCompanion()
        case .acknowledgeTimer:
            manager.acknowledgeTimerExpiry()
            if manager.isRestTimerActive {
                manager.stopTimerFromCompanion()
            }
        case .endWorkout:
            manager.endSession()
        }

        publishCurrentState()
    }
}

extension WatchWorkoutBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.publishCurrentState() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message[WatchWorkoutMessage.requestSnapshotKey] != nil {
            Task { @MainActor in
                let snapshot = self.makeSnapshot()
                let data = try? WatchWorkoutMessage.encode(snapshot)
                replyHandler(data.map { [WatchWorkoutMessage.snapshotKey: $0] } ?? [:])
            }
            return
        }

        guard let data = message[WatchWorkoutMessage.commandKey] as? Data else {
            replyHandler([:])
            return
        }

        Task { @MainActor in
            guard let command = try? WatchWorkoutMessage.decode(WatchWorkoutCommand.self, from: data) else {
                replyHandler([:])
                return
            }
            self.handle(command)
            let snapshot = self.makeSnapshot()
            let data = try? WatchWorkoutMessage.encode(snapshot)
            replyHandler(data.map { [WatchWorkoutMessage.snapshotKey: $0] } ?? [:])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message[WatchWorkoutMessage.commandKey] as? Data else { return }
        Task { @MainActor in
            guard let command = try? WatchWorkoutMessage.decode(WatchWorkoutCommand.self, from: data) else { return }
            self.handle(command)
        }
    }
}
