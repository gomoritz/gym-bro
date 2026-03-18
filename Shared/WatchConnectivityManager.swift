//
//  WatchConnectivityManager.swift
//  gym-bro
//

import Foundation
import SwiftData
import WatchConnectivity

@Observable
class WatchConnectivityManager: NSObject {
    private var wcSession: WCSession?
    var isReachable: Bool = false
    var lastReceivedMessage: WorkoutSyncMessage?

    #if os(watchOS)
    private weak var watchSessionManager: WatchSessionManager?
    private var modelContext: ModelContext?
    #endif

    #if os(iOS)
    private var modelContext: ModelContext?
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
    func configure(sessionManager: WatchSessionManager, modelContext: ModelContext) {
        self.watchSessionManager = sessionManager
        self.modelContext = modelContext
        // Process any applicationContext that arrived before configure was called
        if let session = wcSession, !session.receivedApplicationContext.isEmpty {
            handleReceivedApplicationContext(session.receivedApplicationContext)
        }
    }
    #endif

    #if os(iOS)
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Sync Splits to Watch (iOS only)

    func syncSplitsToWatch(splits: [Split], locations: [GymLocation], categories: [ExerciseCategory]) {
        guard let session = wcSession, session.activationState == .activated else {
            print("[WatchSync] Session not activated, skipping sync")
            return
        }

        // Build transfer data
        var allExercises: [ExerciseTransferData] = []
        var seenExerciseIds = Set<UUID>()

        let splitData = splits.map { split -> SplitTransferData in
            let exerciseIds = (split.exercises ?? []).map { exercise -> UUID in
                if !seenExerciseIds.contains(exercise.id) {
                    seenExerciseIds.insert(exercise.id)
                    let profiles = (exercise.locationProfiles ?? []).map { profile in
                        LocationProfileTransferData(
                            id: profile.id,
                            locationId: profile.location?.id ?? UUID(),
                            targetWeight: profile.targetWeight,
                            notes: profile.notes
                        )
                    }
                    allExercises.append(ExerciseTransferData(
                        id: exercise.id,
                        name: exercise.name,
                        notes: exercise.notes,
                        targetWeight: exercise.targetWeight,
                        targetSets: exercise.targetSets,
                        minReps: exercise.minReps,
                        maxReps: exercise.maxReps,
                        restTimerDurationOverride: exercise.restTimerDurationOverride,
                        categoryId: exercise.category?.id,
                        locationProfiles: profiles
                    ))
                }
                return exercise.id
            }
            return SplitTransferData(id: split.id, name: split.name, exerciseIds: exerciseIds)
        }

        let locationData = locations.map { location in
            LocationTransferData(id: location.id, name: location.name, sortOrder: location.sortOrder)
        }

        let categoryData = categories.map { category in
            CategoryTransferData(id: category.id, name: category.name)
        }

        let payload = SplitSyncPayload(splits: splitData, locations: locationData, categories: categoryData)

        do {
            let payloadData = try JSONEncoder().encode(payload)
            let exerciseData = try JSONEncoder().encode(allExercises)

            let context: [String: Any] = [
                SyncContextKey.splitSyncPayload: payloadData,
                SyncContextKey.exercises: exerciseData,
            ]
            try session.updateApplicationContext(context)
            print("[WatchSync] Sent \(splits.count) splits, \(allExercises.count) exercises, \(locations.count) locations to Watch")
        } catch {
            print("[WatchSync] Failed to send application context: \(error)")
        }
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

    func sendWorkoutStarted(sessionId: UUID, splitId: UUID?, locationId: UUID?, exerciseId: UUID?, exerciseIndex: Int) {
        var msg = WorkoutSyncMessage(type: .workoutStarted)
        msg.sessionId = sessionId
        msg.splitId = splitId
        msg.locationId = locationId
        msg.exerciseId = exerciseId
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
            #if os(watchOS)
            self.processMessageOnWatch(message)
            #endif
        }
    }

    #if os(watchOS)
    @MainActor
    private func processMessageOnWatch(_ message: WorkoutSyncMessage) {
        guard let sessionManager = watchSessionManager, let modelContext = modelContext else { return }

        switch message.type {
        case .workoutStarted:
            guard let splitId = message.splitId else { return }
            // Find the split in the local store
            let descriptor = FetchDescriptor<Split>(predicate: #Predicate { $0.id == splitId })
            guard let split = (try? modelContext.fetch(descriptor))?.first else {
                print("[WatchSync] Could not find split \(splitId) for remote workout start")
                return
            }
            // Find location if provided
            var location: GymLocation?
            if let locationId = message.locationId {
                let locDescriptor = FetchDescriptor<GymLocation>(predicate: #Predicate { $0.id == locationId })
                location = (try? modelContext.fetch(locDescriptor))?.first
            }
            // Resolve exercise index by ID since SwiftData doesn't preserve array ordering
            var exerciseIndex = message.exerciseIndex ?? 0
            if let exerciseId = message.exerciseId,
               let exercises = split.exercises,
               let idx = exercises.firstIndex(where: { $0.id == exerciseId }) {
                exerciseIndex = idx
            }
            sessionManager.startRemoteSession(for: split, location: location, exerciseIndex: exerciseIndex, context: modelContext)

        case .workoutEnded:
            sessionManager.endSession()

        case .exerciseChanged:
            if let exerciseId = message.exerciseId,
               let exercises = sessionManager.currentSplit?.exercises,
               let idx = exercises.firstIndex(where: { $0.id == exerciseId }) {
                sessionManager.currentExerciseIndex = idx
            } else if let exerciseIndex = message.exerciseIndex {
                sessionManager.currentExerciseIndex = exerciseIndex
            }

        case .timerStarted:
            if let duration = message.timerDuration {
                sessionManager.timerManager.start(duration: duration)
            }

        case .timerStopped:
            sessionManager.timerManager.stop()

        default:
            break
        }
    }
    #endif

    #if os(watchOS)
    private func handleReceivedApplicationContext(_ context: [String: Any]) {
        guard let modelContext = self.modelContext else {
            print("[WatchSync] No model context available, cannot process sync")
            return
        }

        guard let payloadData = context[SyncContextKey.splitSyncPayload] as? Data,
              let exerciseData = context[SyncContextKey.exercises] as? Data else {
            print("[WatchSync] No sync data in application context")
            return
        }

        do {
            let payload = try JSONDecoder().decode(SplitSyncPayload.self, from: payloadData)
            let exercises = try JSONDecoder().decode([ExerciseTransferData].self, from: exerciseData)

            Task { @MainActor [modelContext] in
                Self.applySyncData(payload: payload, exercises: exercises, to: modelContext)
            }
        } catch {
            print("[WatchSync] Failed to decode sync data: \(error)")
        }
    }

    @MainActor
    private static func applySyncData(payload: SplitSyncPayload, exercises: [ExerciseTransferData], to context: ModelContext) {
        print("[WatchSync] Applying sync: \(payload.splits.count) splits, \(exercises.count) exercises, \(payload.locations.count) locations")

        // 1. Upsert categories
        var categoryMap: [UUID: ExerciseCategory] = [:]
        for catData in payload.categories {
            let descriptor = FetchDescriptor<ExerciseCategory>(predicate: #Predicate { $0.id == catData.id })
            let existing = (try? context.fetch(descriptor))?.first
            if let existing {
                existing.name = catData.name
                categoryMap[catData.id] = existing
            } else {
                let category = ExerciseCategory(id: catData.id, name: catData.name)
                context.insert(category)
                categoryMap[catData.id] = category
            }
        }

        // 2. Upsert locations
        var locationMap: [UUID: GymLocation] = [:]
        for locData in payload.locations {
            let descriptor = FetchDescriptor<GymLocation>(predicate: #Predicate { $0.id == locData.id })
            let existing = (try? context.fetch(descriptor))?.first
            if let existing {
                existing.name = locData.name
                existing.sortOrder = locData.sortOrder
                locationMap[locData.id] = existing
            } else {
                let location = GymLocation(id: locData.id, name: locData.name, sortOrder: locData.sortOrder)
                context.insert(location)
                locationMap[locData.id] = location
            }
        }

        // 3. Upsert exercises
        var exerciseMap: [UUID: Exercise] = [:]
        for exData in exercises {
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exData.id })
            let existing = (try? context.fetch(descriptor))?.first
            if let existing {
                existing.name = exData.name
                existing.notes = exData.notes
                existing.targetWeight = exData.targetWeight
                existing.targetSets = exData.targetSets
                existing.minReps = exData.minReps
                existing.maxReps = exData.maxReps
                existing.restTimerDurationOverride = exData.restTimerDurationOverride
                existing.category = exData.categoryId.flatMap { categoryMap[$0] }
                exerciseMap[exData.id] = existing

                // Update location profiles
                updateLocationProfiles(for: existing, from: exData.locationProfiles, locationMap: locationMap, context: context)
            } else {
                let exercise = Exercise(
                    id: exData.id,
                    name: exData.name,
                    notes: exData.notes,
                    targetWeight: exData.targetWeight,
                    targetSets: exData.targetSets,
                    minReps: exData.minReps,
                    maxReps: exData.maxReps,
                    restTimerDurationOverride: exData.restTimerDurationOverride
                )
                exercise.category = exData.categoryId.flatMap { categoryMap[$0] }
                context.insert(exercise)
                exerciseMap[exData.id] = exercise

                // Create location profiles
                for profileData in exData.locationProfiles {
                    if let location = locationMap[profileData.locationId] {
                        let profile = ExerciseLocationProfile(
                            id: profileData.id,
                            targetWeight: profileData.targetWeight,
                            notes: profileData.notes,
                            exercise: exercise,
                            location: location
                        )
                        context.insert(profile)
                    }
                }
            }
        }

        // 4. Upsert splits and wire up exercise relationships
        for splitData in payload.splits {
            let descriptor = FetchDescriptor<Split>(predicate: #Predicate { $0.id == splitData.id })
            let existing = (try? context.fetch(descriptor))?.first
            let splitExercises = splitData.exerciseIds.compactMap { exerciseMap[$0] }

            if let existing {
                existing.name = splitData.name
                existing.exercises = splitExercises
            } else {
                let split = Split(id: splitData.id, name: splitData.name, exercises: splitExercises)
                context.insert(split)
            }
        }

        // 5. Delete splits that no longer exist on iPhone
        let activeSplitIds = Set(payload.splits.map { $0.id })
        let allSplitsDescriptor = FetchDescriptor<Split>()
        if let allSplits = try? context.fetch(allSplitsDescriptor) {
            for split in allSplits where !activeSplitIds.contains(split.id) {
                context.delete(split)
            }
        }

        do {
            try context.save()
            print("[WatchSync] Successfully saved sync data")
        } catch {
            print("[WatchSync] Failed to save sync data: \(error)")
        }
    }

    @MainActor
    private static func updateLocationProfiles(for exercise: Exercise, from profiles: [LocationProfileTransferData], locationMap: [UUID: GymLocation], context: ModelContext) {
        // Remove old profiles
        if let existingProfiles = exercise.locationProfiles {
            for profile in existingProfiles {
                context.delete(profile)
            }
        }
        // Create new profiles
        for profileData in profiles {
            if let location = locationMap[profileData.locationId] {
                let profile = ExerciseLocationProfile(
                    id: profileData.id,
                    targetWeight: profileData.targetWeight,
                    notes: profileData.notes,
                    exercise: exercise,
                    location: location
                )
                context.insert(profile)
            }
        }
    }
    #endif
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
        if activationState == .activated {
            #if os(watchOS)
            // Check for any pending applicationContext
            if !session.receivedApplicationContext.isEmpty {
                handleReceivedApplicationContext(session.receivedApplicationContext)
            }
            #endif
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

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        #if os(watchOS)
        handleReceivedApplicationContext(applicationContext)
        #endif
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
