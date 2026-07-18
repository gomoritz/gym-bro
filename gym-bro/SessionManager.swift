//
//  SessionManager.swift
//  gym-bro
//
//  Created by Moritz Goessl on 12.01.26.
//

import Foundation
import SwiftData
import UIKit

@Observable
class SessionManager: Identifiable, Hashable {
    let id = UUID()

    // MARK: - Dependencies

    let timerManager = TimerManager()
    private var settings: Settings?
    private var modelContext: ModelContext?

    // MARK: - Session State

    var currentSplit: Split?
    var pendingSplit: Split?
    var currentExerciseIndex: Int = 0
    var transitionToExercise: Exercise?
    var activeSession: WorkoutSession?
    var currentLocation: GymLocation?

    var isChoosingNextExercise: Bool = false
    var isChoosingStartingExercise: Bool = false
    var isChoosingReplacement: Bool = false

    // MARK: - Timer Forwarding

    var isRestTimerActive: Bool { timerManager.isActive }
    var restTimerDuration: TimeInterval { timerManager.duration }
    var restTimeRemaining: TimeInterval { timerManager.timeRemaining }
    var timerEndDate: Date? { timerManager.projectedEndTime }
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

    var categoryAlternatives: [Exercise] {
        guard let exercise = currentExercise,
              let category = exercise.category,
              let exercises = category.exercises else {
            return []
        }
        return exercises.filter { $0.id != exercise.id }
    }

    // MARK: - Session Management

    func configure(settings: Settings) {
        self.settings = settings
        setupTimerCallbacks()
        WatchWorkoutBridge.shared.connect(to: self)
    }

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

        let exerciseName = currentExercise?.name
        let setNum = currentSetNumber

        print("Starting session with \(split.exercises?.count ?? 0) exercises")

        Task { @MainActor in
            if let name = exerciseName {
                WorkoutLiveActivityManager.shared.startWorkoutActivity(
                    exerciseName: name,
                    setNumber: setNum
                )
            }
            WatchWorkoutBridge.shared.startCompanionWorkout()
        }
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
        WatchWorkoutBridge.shared.publishCurrentState()
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
        WatchWorkoutBridge.shared.publishCurrentState()
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

    func replaceCurrentExercise(with replacement: Exercise) {
        guard let split = currentSplit,
              split.exercises != nil,
              currentExerciseIndex < split.exercises!.count else {
            return
        }

        split.exercises![currentExerciseIndex] = replacement
        isChoosingReplacement = false

        Task { @MainActor in
            WorkoutLiveActivityManager.shared.startWorkoutActivity(
                exerciseName: replacement.name,
                setNumber: currentSetNumber
            )
            WatchWorkoutBridge.shared.publishCurrentState()
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
            startSessionWithExercise(at: index)
        } else {
            if isRestTimerActive {
                stopTimer()
            }
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

        activeSession = nil
        currentSplit = nil
        currentExerciseIndex = 0
        transitionToExercise = nil
        currentLocation = nil

        if isRestTimerActive {
            toggleTimer()
        }

        Task { @MainActor in
            WorkoutLiveActivityManager.shared.endWorkoutActivity()
            WatchWorkoutBridge.shared.publishCurrentState()
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
        Task { @MainActor in
            WorkoutLiveActivityManager.shared.requestNotificationAuthorization()
        }

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
        WatchWorkoutBridge.shared.publishCurrentState()

        // Update live activity
        if let transition = transitionToExercise {
            let target = transition.targetString(for: currentLocation)
            let notes = transition.effectiveNotes(for: currentLocation)
            Task { @MainActor in
                WorkoutLiveActivityManager.shared.startTransitionTimer(
                    nextExerciseName: transition.name,
                    target: target,
                    notes: notes,
                    duration: duration
                )
            }
        } else if let exercise = currentExercise {
            Task { @MainActor in
                WorkoutLiveActivityManager.shared.startRestTimer(
                    currentExerciseName: exercise.name,
                    currentSetNumber: currentSetNumber,
                    duration: duration
                )
            }
        }
    }

    private func stopTimer() {
        timerManager.stop()

        if transitionToExercise != nil {
            transitionToExercise = nil
        }

        if let exercise = currentExercise {
            Task { @MainActor in
                WorkoutLiveActivityManager.shared.updateToIdle(
                    exerciseName: exercise.name,
                    setNumber: currentSetNumber
                )
            }
        }
        WatchWorkoutBridge.shared.publishCurrentState()
    }

    func stopTimerFromCompanion() {
        stopTimer()
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
            timerManager.acknowledgeExpiry()
            WatchWorkoutBridge.shared.publishCurrentState()
        }
    }

    // MARK: - Private

    private func setupTimerCallbacks() {
        timerManager.onTimerExpired = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if let transition = self.transitionToExercise {
                    WorkoutLiveActivityManager.shared.setTransitionTimerExpired(
                        nextExerciseName: transition.name,
                        target: transition.targetString(for: self.currentLocation),
                        notes: transition.effectiveNotes(for: self.currentLocation)
                    )
                } else if let exercise = self.currentExercise {
                    WorkoutLiveActivityManager.shared.setRestTimerExpired(
                        currentExerciseName: exercise.name,
                        currentSetNumber: self.currentSetNumber
                    )
                }
                WatchWorkoutBridge.shared.publishCurrentState()
            }
        }
    }

    // MARK: - Hashable Conformance

    static func == (lhs: SessionManager, rhs: SessionManager) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
