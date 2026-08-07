//
//  ActiveSessionView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 12.01.26.
//

import SwiftData
import SwiftUI

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Full session history, used by the cross-gym weight-ratio engine so the
    // increase-reminder banner can compute a location-adjusted suggestion
    // instead of degrading to the 1:1 "No data" fallback.
    @Query private var allSessions: [WorkoutSession]

    @State var sessionManager: SessionManager

    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var duration: String = ""
    @State private var showEndSessionAlert = false
    @State private var showSkipConfirmation = false
    @State private var showReplacementPicker = false
    @State private var showExerciseEditor = false
    @State private var setLogged = false
    @State private var reminderDismissed = false
    @State private var editingSet: WorkoutSet?
    @State private var setPendingDeletion: WorkoutSet?

    @FocusState private var focusedField: Field?
    enum Field { case weight, reps, duration }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    exerciseHeader

                    if let exercise = sessionManager.currentExercise {
                        increaseReminderBanner

                        progressionSuggestionBanner

                        setHistorySection

                        if exercise.hasTarget {
                            weightRepsInputs
                        } else {
                            durationInput
                        }
                    }
                }
                .padding()
                .padding(.bottom, 200)
            }
            .scrollDismissesKeyboard(.interactively)

            floatingActionArea
        }
        .navigationTitle("Active Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: Binding(
            get: { sessionManager.isRestTimerActive },
            set: { _ in }
        )) {
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
                if let exercise = sessionManager.currentExercise {
                    NavigationLink(destination: ExerciseStatsDetailView(exercise: exercise, location: sessionManager.currentLocation)) {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityIdentifier("exerciseStatsButton")
                }
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
        .sheet(isPresented: $showExerciseEditor, onDismiss: {
            updateInputDefaults()
        }) {
            NavigationStack {
                ExerciseFormView(exercise: sessionManager.currentExercise)
            }
        }
        .sheet(item: $editingSet, onDismiss: {
            updateInputDefaults()
        }) { set in
            SetEditorSheet(mode: .edit(set), onSave: {
                updateInputDefaults()
            })
        }
        .confirmationDialog(
            "Delete Set?",
            isPresented: Binding(
                get: { setPendingDeletion != nil },
                set: { if !$0 { setPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Set", role: .destructive) {
                if let set = setPendingDeletion {
                    WorkoutPersistence.deleteSet(set, in: modelContext)
                    updateInputDefaults()
                }
                setPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                setPendingDeletion = nil
            }
        } message: {
            Text("This set will be permanently removed. If it is the exercise's only set in this workout, the exercise will count as skipped.")
        }
        .onAppear {
            updateInputDefaults()
        }
        .onChange(of: sessionManager.currentExerciseIndex) {
            updateInputDefaults()
        }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let exercise = sessionManager.currentExercise {
                VStack(spacing: Theme.Spacing.sm) {
                    Text(exercise.name)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)

                    HStack(spacing: Theme.Spacing.md) {
                        if let progressText = exerciseProgressText {
                            Text(progressText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            showExerciseEditor = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(.subheadline)
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

                    if let notes = exercise.effectiveNotes(for: sessionManager.currentLocation),
                       !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, Theme.Spacing.xs)
                    }
                }

                if exercise.hasTarget {
                    HStack(spacing: Theme.Spacing.lg) {
                        Label {
                            if let targetSets = exercise.targetSets {
                                Text("Set \(sessionManager.currentSetNumber) of \(targetSets)")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .contentTransition(.numericText())
                            } else {
                                Text("Set \(sessionManager.currentSetNumber)")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .contentTransition(.numericText())
                            }
                        } icon: {
                            Image(systemName: "list.number")
                                .foregroundStyle(.blue)
                        }

                        Divider()
                            .frame(height: 20)

                        if let effectiveWeight = exercise.effectiveTargetWeight(for: sessionManager.currentLocation),
                           let minReps = exercise.minReps,
                           let maxReps = exercise.maxReps
                        {
                            Text("\(String(format: "%.1f", effectiveWeight))kg x \(minReps)-\(maxReps)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .background(.regularMaterial, in: .capsule)
                }
            } else {
                Text("No exercise")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Increase Reminder Banner

    @ViewBuilder
    private var increaseReminderBanner: some View {
        if !reminderDismissed,
           let exercise = sessionManager.currentExercise,
           let location = sessionManager.currentLocation,
           let profile = exercise.profile(for: location),
           !profile.increaseAcknowledged,
           let sourceProfile = exercise.mostRecentIncrease(excluding: location),
           let sourceLocation = sourceProfile.location,
           let newWeight = sourceProfile.targetWeight
        {
            let suggestion = WeightRatioEngine.suggestWeight(
                for: exercise,
                from: sourceLocation,
                to: location,
                newSourceWeight: newWeight,
                allSessions: allSessions
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weight increased at \(sourceLocation.name)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let previous = sourceProfile.previousWeight {
                            Text("\(String(format: "%.1f", previous))kg → \(String(format: "%.1f", newWeight))kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Text("Suggested: \(String(format: "%.1f", suggestion.suggestedWeight))kg")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))

                    Text("(\(suggestion.confidence.label))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        profile.targetWeight = suggestion.suggestedWeight
                        profile.increaseAcknowledged = true
                        weight = String(format: "%.1f", suggestion.suggestedWeight)
                        withAnimation { reminderDismissed = true }
                    } label: {
                        Text("Apply \(String(format: "%.1f", suggestion.suggestedWeight))kg")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                            .foregroundStyle(.orange)
                    }

                    Button {
                        profile.increaseAcknowledged = true
                        withAnimation { reminderDismissed = true }
                    } label: {
                        Text("Ignore")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
    }

    // MARK: - Progression Suggestion Banner

    @ViewBuilder
    private var progressionSuggestionBanner: some View {
        if let exercise = sessionManager.currentExercise,
           exercise.hasTarget,
           let suggestion = ProgressionEngine.evaluate(exercise: exercise, at: sessionManager.currentLocation),
           suggestion.suggestsIncrease
        {
            ProgressionBannerView(suggestion: suggestion)
        }
    }

    // MARK: - Set History

    private var setHistorySection: some View {
        Group {
            if let session = sessionManager.activeSession,
               let currentEx = sessionManager.currentExercise,
               let sets = session.sets?.filter({ $0.exercise?.id == currentEx.id }),
               !sets.isEmpty
            {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("This Exercise")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(Array(sets.sorted(by: { $0.startTime < $1.startTime }).enumerated()), id: \.element.id) { index, workoutSet in
                        Button {
                            editingSet = workoutSet
                        } label: {
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)

                                if let w = workoutSet.weight, let r = workoutSet.reps {
                                    Text("\(String(format: "%.1f", w)) kg x \(r)")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                } else if let d = workoutSet.duration {
                                    Text("\(d) min")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                editingSet = workoutSet
                            } label: {
                                Label("Edit Set", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                setPendingDeletion = workoutSet
                            } label: {
                                Label("Delete Set", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }

    // MARK: - Weight & Reps Inputs

    private var weightRepsInputs: some View {
        VStack(spacing: Theme.Spacing.lg) {
            inputField(
                label: "Weight (kg)",
                text: $weight,
                field: .weight,
                keyboardType: .decimalPad
            )
            .onChange(of: weight) { _, newValue in
                weight = newValue.replacingOccurrences(of: ",", with: ".")
            }

            inputField(
                label: "Reps",
                text: $reps,
                field: .reps,
                keyboardType: .numberPad
            )
        }
        .padding(.horizontal)
    }

    private var durationInput: some View {
        inputField(
            label: "Duration (minutes)",
            text: $duration,
            field: .duration,
            keyboardType: .numberPad
        )
        .padding(.horizontal)
    }

    private func inputField(label: String, text: Binding<String>, field: Field, keyboardType: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("0", text: text)
                .focused($focusedField, equals: field)
                .keyboardType(keyboardType)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.horizontal)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .frame(minHeight: Theme.TouchTarget.large)
        }
    }

    // MARK: - Floating Action Area

    private var floatingActionArea: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let exercise = sessionManager.currentExercise {
                if exercise.hasTarget {
                    if sessionManager.hasReachedCurrentExerciseTarget {
                        finishExerciseButton(isPrimary: true)
                        HStack(spacing: Theme.Spacing.md) {
                            finishSetButton(isPrimary: false)
                            skipButton
                        }
                    } else {
                        finishSetButton(isPrimary: true)
                        HStack(spacing: Theme.Spacing.md) {
                            finishExerciseButton(isPrimary: false)
                            skipButton
                        }
                    }
                } else {
                    finishExerciseButton(isPrimary: true)
                    skipButton
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xxxl)
        .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.xl, topTrailingRadius: Theme.Radius.xl))
    }

    private func finishSetButton(isPrimary: Bool) -> some View {
        Button(action: finishSet) {
            Text("Log Set")
                .font(isPrimary ? .system(.title2, design: .rounded, weight: .bold) : .system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : .blue)
                .frame(maxWidth: .infinity)
                .frame(minHeight: isPrimary ? Theme.TouchTarget.large : Theme.TouchTarget.comfortable)
                .background {
                    if isPrimary {
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .fill(Color.blue.gradient)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(.blue.opacity(0.15))
                    }
                }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: setLogged)
    }

    private func finishExerciseButton(isPrimary: Bool) -> some View {
        Button(action: finishExercise) {
            HStack {
                Text("Finish Exercise")
                    .font(isPrimary ? .system(.title2, design: .rounded, weight: .bold) : .system(.headline, design: .rounded, weight: .semibold))
                if !isPrimary {
                    Image(systemName: "arrow.right")
                }
            }
            .foregroundStyle(isPrimary ? .white : .blue)
            .frame(maxWidth: .infinity)
            .frame(minHeight: isPrimary ? Theme.TouchTarget.large : Theme.TouchTarget.comfortable)
            .background {
                if isPrimary {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .fill(Color.blue.gradient)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(.blue.opacity(0.15))
                }
            }
        }
    }

    private var skipButton: some View {
        Button(action: {
            showSkipConfirmation = true
        }) {
            Text(isFirstSet ? "Skip" : "Skip Rest")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.TouchTarget.comfortable)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(.orange.opacity(0.15))
                )
        }
    }

    // MARK: - Computed Properties

    private var exerciseProgressText: String? {
        guard let split = sessionManager.currentSplit,
              let exercises = split.exercises,
              let session = sessionManager.activeSession else { return nil }

        let currentExerciseId = sessionManager.currentExercise?.id
        let completedExerciseIds = Set((session.sets ?? [])
            .compactMap { $0.exercise?.id }
            .filter { $0 != currentExerciseId })

        let completedCount = completedExerciseIds.count
        let currentNumber = completedCount + 1

        return "\(currentNumber)/\(exercises.count)"
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
            guard let weightValue = Double(weight),
                  let repsValue = Int(reps),
                  weightValue > 0,
                  repsValue > 0
            else {
                return
            }

            let success = sessionManager.completeSet(weight: weightValue, reps: repsValue)
            setLogged.toggle()
            if !success {
                showEndSessionAlert = true
            }
        } else {
            guard let durationValue = Int(duration),
                  durationValue > 0
            else {
                return
            }
            sessionManager.logDurationSet(minutes: durationValue)
            setLogged.toggle()
            sessionManager.startTimer()
        }
    }

    private func finishExercise() {
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

        let success = sessionManager.nextExercise()
        if !success {
            showEndSessionAlert = true
        }
    }

    private func skipSets() {
        let success = sessionManager.nextExercise()
        if !success {
            showEndSessionAlert = true
        }
    }

    private func updateInputDefaults() {
        reminderDismissed = false

        guard let exercise = sessionManager.currentExercise else {
            weight = ""
            reps = ""
            duration = ""
            return
        }

        if exercise.hasTarget {
            if let lastSet = sessionManager.lastSetForCurrentExercise {
                weight = String(format: "%.1f", lastSet.weight ?? 0)
                reps = "\(lastSet.reps ?? 0)"
            } else {
                if let effectiveWeight = exercise.effectiveTargetWeight(for: sessionManager.currentLocation) {
                    weight = String(format: "%.1f", effectiveWeight)
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
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                if let target = exercise.targetString {
                                    Text(target)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            .frame(minHeight: Theme.TouchTarget.minimum)
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
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    Text(exercise.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if let target = exercise.targetString {
                                        Text(target)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, Theme.Spacing.xs)
                                .frame(minHeight: Theme.TouchTarget.minimum)
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
}

private struct ProgressionBannerView: View {
    let suggestion: ProgressionSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                    .font(.title3)

                Text("Time to level up")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()
            }

            ForEach(Array(suggestion.triggers.enumerated()), id: \.offset) { _, trigger in
                VStack(alignment: .leading, spacing: 2) {
                    Text(trigger.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(trigger.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Consider ~\(ProgressionEngine.formatWeight(suggestion.suggestedWeight))")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.green)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

#Preview {
    NavigationStack {
        ActiveSessionView(sessionManager: SessionManager())
    }
}

#Preview("Progression Banner") {
    ProgressionBannerView(suggestion: .sampleSuggestion)
        .padding()
}
