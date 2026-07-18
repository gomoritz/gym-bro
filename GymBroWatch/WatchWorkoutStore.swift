import Foundation
import WatchConnectivity

@MainActor
@Observable
final class WatchWorkoutStore: NSObject {
    private(set) var snapshot: WatchWorkoutSnapshot
    private(set) var connectionError: String?
    private let defaultsKey = "lastWorkoutSnapshot"

    override init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? WatchWorkoutMessage.decode(WatchWorkoutSnapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = .idle
        }

        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func requestLatestState() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let session = WCSession.default

        if let contextData = session.receivedApplicationContext[WatchWorkoutMessage.snapshotKey] as? Data {
            apply(contextData)
        }

        guard session.isReachable else { return }
        session.sendMessage(
            [WatchWorkoutMessage.requestSnapshotKey: true],
            replyHandler: { [weak self] reply in
                guard let data = reply[WatchWorkoutMessage.snapshotKey] as? Data else { return }
                Task { @MainActor in self?.apply(data) }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in self?.connectionError = error.localizedDescription }
            }
        )
    }

    func logSet(weight: Double, reps: Int) {
        send(.logSet(weight: weight, reps: reps))
    }

    func selectExercise(id: UUID) {
        send(.selectExercise(id: id))
    }

    func stopTimer() {
        send(.stopTimer)
    }

    func acknowledgeTimer() {
        send(.acknowledgeTimer)
    }

    func endWorkout() {
        send(.endWorkout)
    }

    private func send(_ command: WatchWorkoutCommand) {
        connectionError = nil
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let data = try? WatchWorkoutMessage.encode(command) else {
            connectionError = "Apple Watch is not connected to Gym Bro."
            return
        }

        let session = WCSession.default
        guard session.isReachable else {
            connectionError = "Keep Gym Bro running on your iPhone and try again."
            return
        }

        session.sendMessage(
            [WatchWorkoutMessage.commandKey: data],
            replyHandler: { [weak self] reply in
                guard let data = reply[WatchWorkoutMessage.snapshotKey] as? Data else { return }
                Task { @MainActor in self?.apply(data) }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in self?.connectionError = error.localizedDescription }
            }
        )
    }

    private func apply(_ data: Data) {
        guard let incoming = try? WatchWorkoutMessage.decode(WatchWorkoutSnapshot.self, from: data),
              incoming.revision >= snapshot.revision || incoming.sessionID != snapshot.sessionID else { return }

        let workoutEnded = snapshot.isWorkoutActive && !incoming.isWorkoutActive
        snapshot = incoming
        UserDefaults.standard.set(data, forKey: defaultsKey)
        connectionError = nil

        if workoutEnded {
            WatchHealthWorkoutManager.shared.endWorkout()
        }
    }
}

extension WatchWorkoutStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.requestLatestState() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchWorkoutMessage.snapshotKey] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message[WatchWorkoutMessage.snapshotKey] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
}
