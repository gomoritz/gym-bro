//
//  SessionManager.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import Foundation
import SwiftData
import UIKit
import AudioToolbox

@Observable
class SessionManager: Identifiable, Hashable {
    let id = UUID()
    
    var currentSplit: Split?
    var pendingSplit: Split?
    var currentExerciseIndex: Int = 0
    var transitionToExercise: Exercise?
    var isRestTimerActive: Bool = false
    var restTimerDuration: TimeInterval = 120 // Default 2 minutes
    var restTimeRemaining: TimeInterval = 120
    var activeSession: WorkoutSession?
    var isTimerExpired: Bool = false
    
    var isChoosingNextExercise: Bool = false
    var isChoosingStartingExercise: Bool = false
    var isChoosingReplacement: Bool = false
    
    private var modelContext: ModelContext?
    private var timer: Timer?
    private var timerEndTime: Date?
    
    // MARK: - Computed Properties
    
    var currentExercise: Exercise? {
        guard let split = currentSplit,
              let exercises = split.exercises,
              currentExerciseIndex < exercises.count else {
            return nil
        }
        return exercises[currentExerciseIndex]
    }
    
    var currentSetNumber: Int {
        guard let session = activeSession,
              let currentEx = currentExercise,
              let sets = session.sets else {
            return 1
        }
        
        // Count how many sets have been logged for the current exercise
        let setsForCurrentExercise = sets.filter { $0.exercise?.id == currentEx.id }
        return setsForCurrentExercise.count + 1
    }
    
    var lastSet: WorkoutSet? {
        guard let session = activeSession,
              let sets = session.sets else {
            return nil
        }

        // Get the most recent set overall (not just for current exercise)
        return sets
            .sorted { $0.startTime > $1.startTime }
            .first
    }

    var lastSetForCurrentExercise: WorkoutSet? {
        guard let session = activeSession,
              let currentEx = currentExercise,
              let sets = session.sets else {
            return nil
        }

        // Get the most recent set for the current exercise
        return sets
            .filter { $0.exercise?.id == currentEx.id }
            .sorted { $0.startTime > $1.startTime }
            .first
    }
    
    var isSessionActive: Bool {
        return activeSession != nil
    }

    var remainingExercisesInSplit: [Exercise] {
        guard let split = currentSplit,
              let exercises = split.exercises,
              let session = activeSession else {
            return []
        }
        
        let completedExerciseIds = Set((session.sets ?? []).compactMap { $0.exercise?.id })
        let currentExerciseId = currentExercise?.id
        
        return exercises.filter { exercise in
            exercise.id != currentExerciseId && !completedExerciseIds.contains(exercise.id)
        }
    }
    
    var categoryAlternatives: [Exercise] {
        guard let exercise = currentExercise,
              let category = exercise.category,
              let exercises = category.exercises else {
            return []
        }
        return exercises.filter { $0.id != exercise.id }
    }

    // MARK: - Session Management
    
    func startSession(for split: Split, context: ModelContext) {
        self.pendingSplit = split
        self.modelContext = context
        
        // Show exercise picker if multiple exercises
        if let exercises = split.exercises, exercises.count > 1 {
            self.isChoosingStartingExercise = true
        } else {
            // Only one exercise, start immediately
            startSessionWithExercise(at: 0)
        }
    }
    
    func startSessionWithExercise(at index: Int) {
        guard let split = pendingSplit else { return }
        
        self.currentSplit = split
        self.currentExerciseIndex = index
        self.transitionToExercise = nil
        self.modelContext = modelContext
        self.isTimerExpired = false
        
        let session = WorkoutSession(
            startTime: Date.now,
            split: split,
            splitName: split.name,
            splitId: split.id
        )
        
        if let context = modelContext {
            context.insert(session)
        }
        self.activeSession = session
        self.pendingSplit = nil
        
        // Capture values before the Task to avoid race conditions
        let exerciseName = currentExercise?.name
        let setNum = currentSetNumber
        
        print("📋 Starting session with \(split.exercises?.count ?? 0) exercises")
        
        // Start the live activity for the workout
        Task { @MainActor in
            if let name = exerciseName {
                WorkoutLiveActivityManager.shared.startWorkoutActivity(
                    exerciseName: name,
                    setNumber: setNum
                )
            } else {
                print("⚠️  Warning: Could not start live activity - no current exercise")
            }
        }
    }
    
    func logSet(weight: Double, reps: Int) {
        guard let session = activeSession,
              let exercise = currentExercise,
              let context = modelContext else {
            return
        }

        let now = Date.now

        // Calculate rest duration if there was a previous set
        if let previous = lastSet {
            let restTaken = now.timeIntervalSince(previous.startTime)
            previous.restDuration = restTaken
            previous.restTimerUsed = isRestTimerActive || isTimerExpired
        }

        // Create a new WorkoutSet with completion time
        let workoutSet = WorkoutSet(
            startTime: now,
            weight: weight,
            reps: reps,
            exercise: exercise,
            session: session,
            endTime: now  // Set is completed immediately when logged
        )

        context.insert(workoutSet)

        // Add to session's sets
        if session.sets == nil {
            session.sets = []
        }
        session.sets?.append(workoutSet)

        // Add to exercise's history
        if exercise.history == nil {
            exercise.history = []
        }
        exercise.history?.append(workoutSet)

        // Auto-update target weight if conditions are met
        if let minReps = exercise.minReps,
           let targetWeight = exercise.targetWeight,
           reps >= minReps && weight > targetWeight {
            exercise.targetWeight = weight
        }

        // Save the context
        try? context.save()
    }
    
    func logDurationSet(minutes: Int) {
        guard let session = activeSession,
              let exercise = currentExercise,
              let context = modelContext else {
            return
        }

        let now = Date.now

        // Calculate rest duration if there was a previous set
        if let previous = lastSet {
            let restTaken = now.timeIntervalSince(previous.startTime)
            previous.restDuration = restTaken
            previous.restTimerUsed = isRestTimerActive || isTimerExpired
        }

        // Create a new WorkoutSet with duration and completion time
        let workoutSet = WorkoutSet(
            startTime: now,
            duration: minutes,
            exercise: exercise,
            session: session,
            endTime: now  // Set is completed immediately when logged
        )

        context.insert(workoutSet)

        // Add to session's sets
        if session.sets == nil {
            session.sets = []
        }
        session.sets?.append(workoutSet)

        // Add to exercise's history
        if exercise.history == nil {
            exercise.history = []
        }
        exercise.history?.append(workoutSet)

        // Save the context
        try? context.save()
    }
    
    func nextExercise() -> Bool {
        guard let split = currentSplit,
              split.exercises != nil else {
            return false
        }
        
        // Stop the timer if active
        if isRestTimerActive {
            toggleTimer()
        }
        
        let remaining = remainingExercisesInSplit
        
        if remaining.count > 1 {
            isChoosingNextExercise = true
            return true
        } else if let next = remaining.first {
            selectNextExercise(next)
            return true
        }
        
        return false
    }

    func replaceCurrentExercise(with replacement: Exercise) {
        guard let split = currentSplit,
              split.exercises != nil,
              currentExerciseIndex < split.exercises!.count else {
            return
        }

        split.exercises![currentExerciseIndex] = replacement
        isChoosingReplacement = false

        // Update live activity
        Task { @MainActor in
            WorkoutLiveActivityManager.shared.startWorkoutActivity(
                exerciseName: replacement.name,
                setNumber: currentSetNumber
            )
        }
    }

    func selectNextExercise(_ exercise: Exercise) {
        guard let split = currentSplit ?? pendingSplit,
              let exercises = split.exercises,
              let index = exercises.firstIndex(of: exercise) else {
            return
        }
        
        let isStartingExercise = isChoosingStartingExercise
        isChoosingNextExercise = false
        isChoosingStartingExercise = false
        
        if isStartingExercise {
            // Starting a new session - create session with this exercise
            startSessionWithExercise(at: index)
        } else {
            // Moving to next exercise - use transition timer
            currentExerciseIndex = index
            transitionToExercise = exercise
            startTimer()
        }
    }
    
    func endSession() {
        guard let session = activeSession,
              let context = modelContext else {
            return
        }

        session.endTime = Date.now

        // Track actual exercise order performed
        if let sets = session.sets {
            var orderSeen: [UUID] = []
            let sortedSets = sets.sorted { $0.startTime < $1.startTime }

            for set in sortedSets {
                if let exerciseId = set.exercise?.id, !orderSeen.contains(exerciseId) {
                    orderSeen.append(exerciseId)
                }
            }

            session.actualExerciseOrder = orderSeen.isEmpty ? nil : orderSeen
        }

        // Track skipped exercises
        if let split = currentSplit,
           let allExercises = split.exercises,
           let performedOrder = session.actualExerciseOrder {
            let performedIds = Set(performedOrder)
            let skippedIds = allExercises
                .map { $0.id }
                .filter { !performedIds.contains($0) }

            session.skippedExerciseIds = skippedIds.isEmpty ? nil : skippedIds
        }

        try? context.save()

        // Clean up
        activeSession = nil
        currentSplit = nil
        currentExerciseIndex = 0
        transitionToExercise = nil
        isTimerExpired = false

        if isRestTimerActive {
            toggleTimer()
        }

        // End the live activity
        Task { @MainActor in
            WorkoutLiveActivityManager.shared.endWorkoutActivity()
        }
    }
    
    // MARK: - Timer Management
    
    func toggleTimer() {
        if isRestTimerActive {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        // Request notification permission if needed
        Task { @MainActor in
            WorkoutLiveActivityManager.shared.requestNotificationAuthorization()
        }
        
        // Determine timer duration based on context
        let duration: TimeInterval
        if let transition = transitionToExercise {
            // Transition timer uses default transition duration
            duration = Settings.shared.defaultTransitionTimerDuration
        } else {
            // Rest timer: check for exercise override first
            if let exercise = currentExercise,
               let override = exercise.restTimerDurationOverride {
                duration = override
            } else {
                duration = Settings.shared.defaultRestTimerDuration
            }
        }
        
        restTimerDuration = duration
        restTimeRemaining = duration
        timerEndTime = Date().addingTimeInterval(duration)
        isRestTimerActive = true
        isTimerExpired = false
        
        // Determine what type of timer this is
        if let transition = transitionToExercise {
            // Transition timer
            let target = getTargetString(for: transition)
            let notes = transition.notes
            
            Task { @MainActor in
                WorkoutLiveActivityManager.shared.startTransitionTimer(
                    nextExerciseName: transition.name,
                    target: target,
                    notes: notes,
                    duration: duration
                )
            }
        } else {
            // Rest timer
            if let exercise = currentExercise {
                Task { @MainActor in
                    WorkoutLiveActivityManager.shared.startRestTimer(
                        currentExerciseName: exercise.name,
                        currentSetNumber: currentSetNumber,
                        duration: duration
                    )
                }
            }
        }
        
        // Timer fires every 0.1s for smoother UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.timerEndTime else { return }
            
            let remaining = endTime.timeIntervalSinceNow
            
            if remaining > 0 {
                self.restTimeRemaining = remaining
            } else {
                // Timer finished
                self.timer?.invalidate()
                self.timer = nil
                self.restTimeRemaining = 0
                self.isTimerExpired = true
                
                // Trigger Vibration
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                
                // Update Live Activity to show expired state
                Task { @MainActor in
                    if let transition = self.transitionToExercise {
                        WorkoutLiveActivityManager.shared.setTransitionTimerExpired(
                            nextExerciseName: transition.name,
                            target: self.getTargetString(for: transition),
                            notes: transition.notes
                        )
                    } else if let exercise = self.currentExercise {
                        WorkoutLiveActivityManager.shared.setRestTimerExpired(
                            currentExerciseName: exercise.name,
                            currentSetNumber: self.currentSetNumber
                        )
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerEndTime = nil
        isRestTimerActive = false
        isTimerExpired = false
        restTimeRemaining = restTimerDuration
        
        // Clear transition if applicable
        if transitionToExercise != nil {
            transitionToExercise = nil
        }
        
        // Update live activity to show idle state
        if let exercise = currentExercise {
            Task { @MainActor in
                WorkoutLiveActivityManager.shared.updateToIdle(
                    exerciseName: exercise.name,
                    setNumber: currentSetNumber
                )
            }
        }
    }
    
    func acknowledgeTimerExpiry() {
        if isTimerExpired {
            if let exercise = currentExercise {
                Task { @MainActor in
                    WorkoutLiveActivityManager.shared.acknowledgeExpiredTimer(
                        exerciseName: exercise.name,
                        setNumber: currentSetNumber
                    )
                }
            }
            isTimerExpired = false
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: SessionManager, rhs: SessionManager) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    private func getTargetString(for exercise: Exercise) -> String? {
        if exercise.hasTarget {
            var parts: [String] = []
            if let sets = exercise.targetSets {
                parts.append("\(sets) sets")
            }
            if let min = exercise.minReps, let max = exercise.maxReps {
                parts.append("\(min)-\(max) reps")
            }
            if let weight = exercise.targetWeight {
                parts.append("@ \(String(format: "%.1f", weight))kg")
            }
            return parts.joined(separator: " ")
        }
        return nil
    }
}
