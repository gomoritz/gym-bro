//
//  WatchSessionManager.swift
//  gym-bro Watch
//

import Foundation
import SwiftData
import WatchKit

@Observable
class WatchSessionManager: Identifiable {
    let id = UUID()

    // MARK: - Dependencies

    let timerManager = WatchTimerManager()
    let healthKitManager = HealthKitManager()
    private var settings: Settings?
    private(set) var modelContext: ModelContext?

    // MARK: - Session State

    var currentSplit: Split?
    var pendingSplit: Split?
    var currentExerciseIndex: Int = 0
    var transitionToExercise: Exercise?
    var activeSession: WorkoutSession?
    var currentLocation: GymLocation?

    var isChoosingNextExercise: Bool = false
    var isChoosingStartingExercise: Bool = false

    // MARK: - Timer Forwarding

    var isRestTimerActive: Bool { timerManager.isActive }
    var restTimerDuration: TimeInterval { timerManager.duration }
    var restTimeRemaining: TimeInterval { timerManager.timeRemaining }
    var isTimerExpired: Bool {
        get { timerManager.isExpired }
        set { timerManager.isExpired = newValue }
    }

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
        let setsForCurrentExercise = sets.filter { $0.exercise?.id == currentEx.id }
        return setsForCurrentExercise.count + 1
    }

    var lastSet: WorkoutSet? {
        guard let session = activeSession,
              let sets = session.sets else {
            return nil
        }
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

    // MARK: - Configuration

    func configure(settings: Settings, modelContext: ModelContext) {
        self.settings = settings
        self.modelContext = modelContext
        setupTimerCallbacks()
        healthKitManager.requestAuthorization()
    }

    // MARK: - Session Management

    func startSession(for split: Split, location: GymLocation? = nil, context: ModelContext) {
        self.pendingSplit = split
        self.currentLocation = location
        self.modelContext = context

        if let exercises = split.exercises, exercises.count > 1 {
            self.isChoosingStartingExercise = true
        } else {
            startSessionWithExercise(at: 0)
        }
    }

    func startSessionWithExercise(at index: Int) {
        guard let split = pendingSplit, let context = modelContext else { return }

        self.currentSplit = split
        self.currentExerciseIndex = index
        self.transitionToExercise = nil

        let session = WorkoutPersistence.createSession(for: split, at: index, location: currentLocation, in: context)
        self.activeSession = session
        self.pendingSplit = nil

        // Start HealthKit workout session
        healthKitManager.startWorkout()
    }

    func logSet(weight: Double, reps: Int) {
        guard let session = activeSession,
              let exercise = currentExercise,
              let context = modelContext else {
            return
        }
        let wasTimerActive = isRestTimerActive || isTimerExpired
        WorkoutPersistence.logWeightSet(
            weight: weight,
            reps: reps,
            exercise: exercise,
            session: session,
            previousSet: lastSet,
            wasTimerActive: wasTimerActive,
            in: context
        )

        // Haptic feedback on set logged
        WKInterfaceDevice.current().play(.click)
    }

    func logDurationSet(minutes: Int) {
        guard let session = activeSession,
              let exercise = currentExercise,
              let context = modelContext else {
            return
        }
        let wasTimerActive = isRestTimerActive || isTimerExpired
        WorkoutPersistence.logDurationSet(
            minutes: minutes,
            exercise: exercise,
            session: session,
            previousSet: lastSet,
            wasTimerActive: wasTimerActive,
            in: context
        )

        WKInterfaceDevice.current().play(.click)
    }

    func nextExercise() -> Bool {
        guard let split = currentSplit,
              split.exercises != nil else {
            return false
        }

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
            startSessionWithExercise(at: index)
        } else {
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

        WorkoutPersistence.endSession(session, split: currentSplit, in: context)

        // End HealthKit workout
        healthKitManager.endWorkout()

        activeSession = nil
        currentSplit = nil
        currentExerciseIndex = 0
        transitionToExercise = nil
        currentLocation = nil

        if isRestTimerActive {
            toggleTimer()
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
        let duration: TimeInterval
        if transitionToExercise != nil {
            duration = settings?.defaultTransitionTimerDuration ?? Constants.Timer.defaultTransitionDuration
        } else {
            if let exercise = currentExercise,
               let override = exercise.restTimerDurationOverride {
                duration = override
            } else {
                duration = settings?.defaultRestTimerDuration ?? Constants.Timer.defaultRestDuration
            }
        }

        timerManager.start(duration: duration)
    }

    private func stopTimer() {
        timerManager.stop()
        if transitionToExercise != nil {
            transitionToExercise = nil
        }
    }

    func acknowledgeTimerExpiry() {
        if isTimerExpired {
            timerManager.acknowledgeExpiry()
        }
    }

    // MARK: - Private

    private func setupTimerCallbacks() {
        timerManager.onTimerExpired = {
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
