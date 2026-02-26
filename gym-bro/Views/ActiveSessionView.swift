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
    @State private var showSkipConfirmation = false
    @State private var showReplacementPicker = false
    
    @FocusState private var focusedField: Field?
    enum Field { case weight, reps, duration }

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
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("Active Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $sessionManager.isRestTimerActive) {
            RestTimerView(sessionManager: sessionManager)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("End Workout") {
                    showEndSessionAlert = true
                }
                .foregroundStyle(.red)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: WorkoutTimelineView(sessionManager: sessionManager)) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(.blue)
                }
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
        .alert(skipAlertTitle, isPresented: $showSkipConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Skip", role: .destructive) {
                skipSets()
            }
        } message: {
            Text(skipAlertMessage)
        }
        .sheet(isPresented: $sessionManager.isChoosingNextExercise) {
            NextExercisePickerView(sessionManager: sessionManager)
        }
        .sheet(isPresented: $sessionManager.isChoosingStartingExercise) {
            NextExercisePickerView(sessionManager: sessionManager, isStartingExercise: true)
        }
        .sheet(isPresented: $showReplacementPicker, onDismiss: {
            updateInputDefaults()
        }) {
            ReplacementExercisePickerView(sessionManager: sessionManager)
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
                VStack(spacing: 4) {
                    Text(exercise.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Exercise counter and replace button
                    HStack(spacing: 12) {
                        if let progressText = exerciseProgressText {
                            Text(progressText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !sessionManager.categoryAlternatives.isEmpty && isFirstSet {
                            Button {
                                showReplacementPicker = true
                            } label: {
                                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Exercise notes
                    if let notes = exercise.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }

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
                            "\(String(format: "%.1f", targetWeight))kg × \(minReps)-\(maxReps)"
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
                    .focused($focusedField, equals: .weight)
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
                    .focused($focusedField, equals: .reps)
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
                .focused($focusedField, equals: .duration)
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
                    
                    // Skip button
                    skipButton
                } else {
                    // Duration-based exercises: only show Finish Exercise
                    finishExerciseButton(isPrimary: true)
                    
                    // Skip button
                    skipButton
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
    
    private var skipButton: some View {
        Button(action: {
            showSkipConfirmation = true
        }) {
            Text(isFirstSet ? "Skip Exercise" : "Skip Remaining Sets")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
        }
    }

    // MARK: - Computed Properties

    private var exerciseProgressText: String? {
        guard let split = sessionManager.currentSplit,
              let exercises = split.exercises,
              let session = sessionManager.activeSession else { return nil }
        
        // Count unique exercises with logged sets (excluding current)
        let currentExerciseId = sessionManager.currentExercise?.id
        let completedExerciseIds = Set((session.sets ?? [])
            .compactMap { $0.exercise?.id }
            .filter { $0 != currentExerciseId })
        
        let completedCount = completedExerciseIds.count
        let currentNumber = completedCount + 1
        
        return "\(currentNumber)/\(exercises.count)"
    }

    private var hasReachedTargetSets: Bool {
        guard let exercise = sessionManager.currentExercise,
            let targetSets = exercise.targetSets
        else {
            return false
        }
        return sessionManager.currentSetNumber >= targetSets
    }
    
    private var isFirstSet: Bool {
        sessionManager.currentSetNumber == 1
    }
    
    private var skipAlertTitle: String {
        isFirstSet ? "Skip Exercise?" : "Skip Remaining Sets?"
    }
    
    private var skipAlertMessage: String {
        isFirstSet
            ? "Are you sure you want to skip this entire exercise? No sets will be logged."
            : "Are you sure you want to skip the remaining sets of this exercise? Already logged sets will be kept."
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
        sessionManager.startTimer()
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
    
    private func skipSets() {
        // Move to next exercise without logging anything
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
            // Priority: last set for current exercise > target values > empty
            if let lastSet = sessionManager.lastSetForCurrentExercise {
                weight = String(format: "%.1f", lastSet.weight ?? 0)
                reps = "\(lastSet.reps ?? 0)"
            } else {
                if let targetWeight = exercise.targetWeight {
                    weight = String(format: "%.1f", targetWeight)
                } else {
                    weight = ""
                }

                if let maxReps = exercise.maxReps {
                    reps = "\(maxReps)"
                } else if let minReps = exercise.minReps {
                    reps = "\(minReps)"
                } else {
                    reps = ""
                }
            }
            duration = ""
        } else {
            // Duration-based exercise
            if let lastSet = sessionManager.lastSetForCurrentExercise,
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

struct NextExercisePickerView: View {
    var sessionManager: SessionManager
    var isStartingExercise: Bool = false
    @Environment(\.dismiss) var dismiss

    var exercisesToShow: [Exercise] {
        if isStartingExercise {
            return sessionManager.pendingSplit?.exercises ?? []
        } else {
            return sessionManager.remainingExercisesInSplit
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(exercisesToShow) { exercise in
                        Button {
                            sessionManager.selectNextExercise(exercise)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let target = getTargetString(for: exercise) {
                                    Text(target)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text(isStartingExercise ? "Select your starting exercise" : "Select your next exercise")
                } footer: {
                    Text(isStartingExercise ? "Choose which exercise you want to start with." : "Choose which exercise you want to perform next.")
                }
            }
            .navigationTitle(isStartingExercise ? "Starting Exercise" : "Next Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isStartingExercise {
                            sessionManager.isChoosingStartingExercise = false
                        } else {
                            sessionManager.isChoosingNextExercise = false
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

struct ReplacementExercisePickerView: View {
    var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let category = sessionManager.currentExercise?.category {
                    Section {
                        ForEach(sessionManager.categoryAlternatives) { exercise in
                            Button {
                                sessionManager.replaceCurrentExercise(with: exercise)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if let target = getTargetString(for: exercise) {
                                        Text(target)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text(category.name)
                    } footer: {
                        Text("Replace the current exercise with another from the same category.")
                    }
                }
            }
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

#Preview {
    NavigationStack {
        ActiveSessionView(sessionManager: SessionManager())
    }
}
