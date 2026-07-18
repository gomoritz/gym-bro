import SwiftUI

struct WatchWorkoutView: View {
    @State var store: WatchWorkoutStore
    @State private var weight = 20.0
    @State private var reps = 10
    @State private var showExercisePicker = false
    @State private var showEndConfirmation = false

    var body: some View {
        Group {
            if store.snapshot.isWorkoutActive {
                workoutContent
            } else {
                NavigationStack {
                    idleContent
                        .navigationTitle("Gym Bro")
                }
            }
        }
        .onAppear {
            store.requestLatestState()
            updateInputs()
        }
        .onChange(of: store.snapshot.revision) {
            updateInputs()
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView(store: store)
        }
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End Workout", role: .destructive) {
                store.endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var idleContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("Start a workout in Gym Bro on your iPhone.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Refresh") {
                store.requestLatestState()
            }
        }
    }

    private var workoutContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let exercise = store.snapshot.currentExercise {
                    VStack(spacing: 2) {
                        Text(exercise.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        Text(setDescription(for: exercise))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let timerKind = store.snapshot.timerKind {
                        TimerCard(store: store, kind: timerKind)
                    } else {
                        setControls
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Next Exercise", systemImage: "arrow.right.circle.fill")
                    }
                    .disabled(store.snapshot.remainingExercises.isEmpty)
                }

                if let error = store.connectionError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("End Workout", role: .destructive) {
                    showEndConfirmation = true
                }
                .font(.caption)
            }
        }
    }

    private var setControls: some View {
        VStack(spacing: 6) {
            Stepper(value: $weight, in: 0...500, step: 0.5) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Weight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(weight, format: .number.precision(.fractionLength(1)))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text("kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Stepper(value: $reps, in: 1...100) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(reps)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
            }

            Button {
                store.logSet(weight: weight, reps: reps)
            } label: {
                Label("Save Set", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(weight <= 0 || reps <= 0)
        }
    }

    private func setDescription(for exercise: WatchExerciseSnapshot) -> String {
        var text = "Set \(store.snapshot.currentSetNumber)"
        if let targetSets = exercise.targetSets {
            text += " of \(targetSets)"
        }
        if let min = exercise.minReps, let max = exercise.maxReps {
            text += " • \(min)–\(max) reps"
        }
        return text
    }

    private func updateInputs() {
        if let suggestedWeight = store.snapshot.suggestedWeight, suggestedWeight > 0 {
            weight = suggestedWeight
        }
        if let suggestedReps = store.snapshot.suggestedReps, suggestedReps > 0 {
            reps = suggestedReps
        }
    }
}

private struct TimerCard: View {
    @State var store: WatchWorkoutStore
    let kind: WatchTimerKind

    var body: some View {
        VStack(spacing: 6) {
            Text(kind == .rest ? "REST" : "TRANSITION")
                .font(.caption2.weight(.bold))
                .foregroundStyle(kind == .rest ? .blue : .orange)

            if store.snapshot.timerExpired {
                Text("GO")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Button("Done") {
                    store.acknowledgeTimer()
                }
                .buttonStyle(.borderedProminent)
            } else if let endDate = store.snapshot.timerEndDate {
                Text(endDate, style: .timer)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Button("Skip Timer") {
                    store.stopTimer()
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State var store: WatchWorkoutStore

    var body: some View {
        NavigationStack {
            List(store.snapshot.remainingExercises) { exercise in
                Button {
                    store.selectExercise(id: exercise.id)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                        if let weight = exercise.targetWeight,
                           let min = exercise.minReps,
                           let max = exercise.maxReps {
                            Text("\(weight.formatted(.number.precision(.fractionLength(1)))) kg • \(min)–\(max)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Next")
        }
    }
}
