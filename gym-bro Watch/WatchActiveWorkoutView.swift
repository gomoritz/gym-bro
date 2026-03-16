//
//  WatchActiveWorkoutView.swift
//  gym-bro Watch
//

import HealthKit
import SwiftUI

struct WatchActiveWorkoutView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var showEndConfirmation = false
    @State private var showExercisePicker = false

    var body: some View {
        if sessionManager.isRestTimerActive || sessionManager.isTimerExpired {
            WatchRestTimerView()
        } else {
            workoutView
        }
    }

    // MARK: - Workout View

    private var workoutView: some View {
        ScrollView {
            VStack(spacing: 8) {
                exerciseHeader
                heartRateDisplay
                weightInput
                repsInput
                actionButtons
            }
            .padding(.horizontal, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showEndConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End Workout", role: .destructive) {
                sessionManager.endSession()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showExercisePicker) {
            WatchExercisePickerView()
        }
        .sheet(isPresented: Binding(
            get: { sessionManager.isChoosingStartingExercise },
            set: { _ in }
        )) {
            WatchExercisePickerView(isStartingExercise: true)
        }
        .sheet(isPresented: Binding(
            get: { sessionManager.isChoosingNextExercise },
            set: { _ in }
        )) {
            WatchExercisePickerView()
        }
        .onAppear { loadDefaults() }
        .onChange(of: sessionManager.currentExerciseIndex) { loadDefaults() }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        VStack(spacing: 2) {
            if let exercise = sessionManager.currentExercise {
                Text(exercise.name)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let targetSets = exercise.targetSets {
                    Text("Set \(sessionManager.currentSetNumber) of \(targetSets)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Heart Rate

    private var heartRateDisplay: some View {
        Group {
            if let hr = sessionManager.healthKitManager.currentHeartRate {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("\(Int(hr))")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weight Input (Digital Crown)

    private var weightInput: some View {
        VStack(spacing: 2) {
            Text("Weight")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(String(format: "%.1f", weight)) kg")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .focusable()
                .digitalCrownRotation(
                    $weight,
                    from: 0,
                    through: 500,
                    by: 2.5,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Reps Input (+/- Buttons)

    private var repsInput: some View {
        VStack(spacing: 2) {
            Text("Reps")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Button {
                    if reps > 0 { reps -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Text("\(reps)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .frame(minWidth: 30)

                Button {
                    reps += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 6) {
            Button {
                logSet()
            } label: {
                Text("Log Set")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Button {
                    finishExercise()
                } label: {
                    Text("Next")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    showEndConfirmation = true
                } label: {
                    Text("End")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func logSet() {
        guard weight > 0, reps > 0 else { return }
        sessionManager.logSet(weight: weight, reps: reps)
        sessionManager.startTimer()
    }

    private func finishExercise() {
        if weight > 0, reps > 0 {
            sessionManager.logSet(weight: weight, reps: reps)
        }
        let success = sessionManager.nextExercise()
        if !success {
            showEndConfirmation = true
        }
    }

    private func loadDefaults() {
        guard let exercise = sessionManager.currentExercise else { return }

        if let lastSet = sessionManager.lastSetForCurrentExercise {
            weight = lastSet.weight ?? 0
            reps = lastSet.reps ?? 0
        } else {
            weight = exercise.effectiveTargetWeight(for: sessionManager.currentLocation) ?? 0
            reps = exercise.maxReps ?? exercise.minReps ?? 0
        }
    }
}
