//
//  WatchConnectivityManager.swift
//  gym-bro
//

import Foundation
import WatchConnectivity

@Observable
class WatchConnectivityManager: NSObject {
    private var wcSession: WCSession?
    var isReachable: Bool = false
    var lastReceivedMessage: WorkoutSyncMessage?

    #if os(watchOS)
    private weak var watchSessionManager: WatchSessionManager?
    private var modelContext: (any AnyObject)?
    #endif

    override init() {
        super.init()
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }

    #if os(watchOS)
    func configure(sessionManager: WatchSessionManager, modelContext: Any) {
        self.watchSessionManager = sessionManager
    }
    #endif

    // MARK: - Sending Messages

    func sendMessage(_ message: WorkoutSyncMessage) {
        guard let session = wcSession, session.isReachable else {
            // Queue for later delivery
            sendAsUserInfo(message)
            return
        }

        session.sendMessage(message.toDictionary(), replyHandler: nil) { [weak self] error in
            print("WatchConnectivity send failed: \(error.localizedDescription)")
            // Fallback to transferUserInfo
            self?.sendAsUserInfo(message)
        }
    }

    func sendWorkoutStarted(sessionId: UUID, splitId: UUID?, locationId: UUID?, exerciseIndex: Int) {
        var msg = WorkoutSyncMessage(type: .workoutStarted)
        msg.sessionId = sessionId
        msg.splitId = splitId
        msg.locationId = locationId
        msg.exerciseIndex = exerciseIndex
        sendMessage(msg)
    }

    func sendWorkoutEnded(sessionId: UUID) {
        var msg = WorkoutSyncMessage(type: .workoutEnded)
        msg.sessionId = sessionId
        sendMessage(msg)
    }

    func sendSetLogged(sessionId: UUID, exerciseId: UUID, weight: Double?, reps: Int?, duration: Int?, setNumber: Int) {
        var msg = WorkoutSyncMessage(type: .setLogged)
        msg.sessionId = sessionId
        msg.exerciseId = exerciseId
        msg.weight = weight
        msg.reps = reps
        msg.duration = duration
        msg.setNumber = setNumber
        sendMessage(msg)
    }

    func sendExerciseChanged(sessionId: UUID, exerciseId: UUID, exerciseIndex: Int) {
        var msg = WorkoutSyncMessage(type: .exerciseChanged)
        msg.sessionId = sessionId
        msg.exerciseId = exerciseId
        msg.exerciseIndex = exerciseIndex
        sendMessage(msg)
    }

    func sendTimerStarted(duration: TimeInterval) {
        var msg = WorkoutSyncMessage(type: .timerStarted)
        msg.timerDuration = duration
        sendMessage(msg)
    }

    func sendTimerStopped() {
        sendMessage(WorkoutSyncMessage(type: .timerStopped))
    }

    func sendTimerExpired() {
        sendMessage(WorkoutSyncMessage(type: .timerExpired))
    }

    func requestSync() {
        sendMessage(WorkoutSyncMessage(type: .requestSync))
    }

    // MARK: - Private

    private func sendAsUserInfo(_ message: WorkoutSyncMessage) {
        guard let session = wcSession else { return }
        session.transferUserInfo(message.toDictionary())
    }

    private func handleReceivedMessage(_ messageDict: [String: Any]) {
        guard let message = WorkoutSyncMessage.from(dictionary: messageDict) else { return }
        Task { @MainActor in
            self.lastReceivedMessage = message
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
        if activationState == .activated {
            requestSync()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleReceivedMessage(userInfo)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
