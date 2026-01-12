//
//  ActiveSessionView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import SwiftData
import SwiftUI

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var sessionManager: SessionManager

    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var duration: String = ""
    @State private var showEndSessionAlert = false
    @State private var showTimerView = false

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Top section - Exercise info
                exerciseHeader
                    .padding()
                    .background(Color(.systemBackground))

                Divider()

                // Middle section - Inputs
                ScrollView {
                    VStack(spacing: 20) {
                        if let exercise = sessionManager.currentExercise {
                            if exercise.hasTarget {
                                // Weight/Reps inputs for target-based exercises
                                weightRepsInputs
                            } else {
                                // Duration input for non-target exercises
                                durationInput
                            }
                        }

                        // Action buttons
                        actionButtons
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Active Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showTimerView) {
            RestTimerView(sessionManager: sessionManager)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("End Workout") {
                    showEndSessionAlert = true
                }
                .foregroundStyle(.red)
            }
        }
        .alert("End Workout?", isPresented: $showEndSessionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("End", role: .destructive) {
                sessionManager.endSession()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to end this workout session?")
        }
        .onAppear {
            updateInputDefaults()
        }
        .onChange(of: sessionManager.currentExerciseIndex) {
            updateInputDefaults()
        }
    }

    // MARK: - View Components

    private var exerciseHeader: some View {
        VStack(spacing: 8) {
            if let exercise = sessionManager.currentExercise {
                Text(exercise.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if exercise.hasTarget {
                    HStack(spacing: 16) {
                        // Set counter
                        Label {
                            if let targetSets = exercise.targetSets {
                                Text(
                                    "Set \(sessionManager.currentSetNumber) of \(targetSets)"
                                )
                                .font(.title3)
                                .fontWeight(.semibold)
                            } else {
                                Text("Set \(sessionManager.currentSetNumber)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        } icon: {
                            Image(systemName: "list.number")
                                .foregroundStyle(.blue)
                        }

                        // Target info if available
                        Divider()
                            .frame(height: 20)

                        if let targetWeight = exercise.targetWeight,
                            let minReps = exercise.minReps,
                            let maxReps = exercise.maxReps
                        {
                            Text(
                                "\(Int(targetWeight))kg × \(minReps)-\(maxReps)"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No exercise")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weightRepsInputs: some View {
        VStack(spacing: 16) {
            // Weight input
            VStack(alignment: .leading, spacing: 8) {
                Text("Weight (kg)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("0", text: $weight)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .onChange(of: weight) { oldValue, newValue in
                        // Replace comma with period for German keyboards
                        weight = newValue.replacingOccurrences(
                            of: ",",
                            with: "."
                        )
                    }
            }
            .padding(.horizontal)

            // Reps input
            VStack(alignment: .leading, spacing: 8) {
                Text("Reps")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("0", text: $reps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            }
            .padding(.horizontal)
        }
    }

    private var durationInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration (minutes)")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("0", text: $duration)
                .keyboardType(.numberPad)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let exercise = sessionManager.currentExercise {
                if exercise.hasTarget {
                    // Target-based exercises: show both buttons with dynamic priority
                    if hasReachedTargetSets {
                        finishExerciseButton(isPrimary: true)
                        finishSetButton(isPrimary: false)
                    } else {
                        finishSetButton(isPrimary: true)
                        finishExerciseButton(isPrimary: false)
                    }
                } else {
                    // Duration-based exercises: only show Finish Exercise
                    finishExerciseButton(isPrimary: true)
                }
            }
        }
        .padding(.horizontal)
    }

    private func finishSetButton(isPrimary: Bool) -> some View {
        Button(action: finishSet) {
            Text("Finish Set")
                .font(isPrimary ? .title2 : .headline)
                .fontWeight(isPrimary ? .bold : .semibold)
                .foregroundStyle(isPrimary ? .white : .blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isPrimary ? 20 : 16)
                .background(
                    RoundedRectangle(cornerRadius: isPrimary ? 16 : 12)
                        .fill(
                            isPrimary
                                ? AnyShapeStyle(Color.blue.gradient)
                                : AnyShapeStyle(Color.blue.opacity(0.1))
                        )
                )
        }
    }

    private func finishExerciseButton(isPrimary: Bool) -> some View {
        Button(action: finishExercise) {
            HStack {
                Text("Finish Exercise")
                    .font(isPrimary ? .title2 : .headline)
                    .fontWeight(isPrimary ? .bold : .semibold)
                if !isPrimary {
                    Image(systemName: "arrow.right")
                }
            }
            .foregroundStyle(isPrimary ? .white : .blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isPrimary ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: isPrimary ? 16 : 12)
                    .fill(
                        isPrimary
                            ? AnyShapeStyle(Color.blue.gradient)
                            : AnyShapeStyle(Color.blue.opacity(0.1))
                    )
            )
        }
    }

    // MARK: - Computed Properties

    private var hasReachedTargetSets: Bool {
        guard let exercise = sessionManager.currentExercise,
            let targetSets = exercise.targetSets
        else {
            return false
        }
        return sessionManager.currentSetNumber >= targetSets
    }

    // MARK: - Actions

    private func finishSet() {
        guard let exercise = sessionManager.currentExercise else { return }

        if exercise.hasTarget {
            // Log weight/reps set
            guard let weightValue = Double(weight),
                let repsValue = Int(reps),
                weightValue > 0,
                repsValue > 0
            else {
                return
            }

            sessionManager.logSet(weight: weightValue, reps: repsValue)
        } else {
            // Log duration set
            guard let durationValue = Int(duration),
                durationValue > 0
            else {
                return
            }

            sessionManager.logDurationSet(minutes: durationValue)
        }

        // Start the timer and navigate to timer view
        sessionManager.toggleTimer()
        showTimerView = true
    }

    private func finishExercise() {
        // Log any pending set if values are entered
        if let exercise = sessionManager.currentExercise {
            if exercise.hasTarget {
                if let weightValue = Double(weight),
                    let repsValue = Int(reps),
                    weightValue > 0,
                    repsValue > 0
                {
                    sessionManager.logSet(weight: weightValue, reps: repsValue)
                }
            } else {
                if let durationValue = Int(duration),
                    durationValue > 0
                {
                    sessionManager.logDurationSet(minutes: durationValue)
                }
            }
        }

        // Move to next exercise
        let success = sessionManager.nextExercise()
        if !success {
            // No more exercises, show completion
            showEndSessionAlert = true
        }
    }

    private func updateInputDefaults() {
        guard let exercise = sessionManager.currentExercise else {
            weight = ""
            reps = ""
            duration = ""
            return
        }

        if exercise.hasTarget {
            // Priority: last set > target values > empty
            if let lastSet = sessionManager.lastSet {
                weight = String(format: "%.1f", lastSet.weight ?? 0)
                reps = "\(lastSet.reps ?? 0)"
            } else {
                if let targetWeight = exercise.targetWeight {
                    weight = String(format: "%.1f", targetWeight)
                } else {
                    weight = ""
                }

                if let minReps = exercise.minReps {
                    reps = "\(minReps)"
                } else {
                    reps = ""
                }
            }
            duration = ""
        } else {
            // Duration-based exercise
            if let lastSet = sessionManager.lastSet,
                let lastDuration = lastSet.duration
            {
                duration = "\(lastDuration)"
            } else {
                duration = ""
            }
            weight = ""
            reps = ""
        }
    }
}

#Preview {
    NavigationStack {
        ActiveSessionView(sessionManager: SessionManager())
    }
}
