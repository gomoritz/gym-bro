//
//  SetEditorSheet.swift
//  gym-bro
//

import SwiftData
import SwiftUI

struct SetEditorSheet: View {
    enum Mode {
        case edit(WorkoutSet)
        case add(exercise: Exercise, session: WorkoutSession, defaultStartTime: Date, defaultWeight: Double?, defaultReps: Int?, defaultDuration: Int?)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var onSave: (() -> Void)? = nil

    @State private var weight: String
    @State private var reps: String
    @State private var duration: String
    @State private var startTime: Date
    @State private var showDeleteConfirmation = false

    init(mode: Mode, onSave: (() -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .edit(let set):
            _weight = State(initialValue: set.weight.map { String(format: "%.1f", $0) } ?? "")
            _reps = State(initialValue: set.reps.map { "\($0)" } ?? "")
            _duration = State(initialValue: set.duration.map { "\($0)" } ?? "")
            _startTime = State(initialValue: set.startTime)
        case .add(_, _, let defaultStartTime, let defaultWeight, let defaultReps, let defaultDuration):
            _weight = State(initialValue: defaultWeight.map { String(format: "%.1f", $0) } ?? "")
            _reps = State(initialValue: defaultReps.map { "\($0)" } ?? "")
            _duration = State(initialValue: defaultDuration.map { "\($0)" } ?? "")
            _startTime = State(initialValue: defaultStartTime)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isDurationField {
                        HStack {
                            Text("Duration (min)")
                            Spacer()
                            TextField("0", text: $duration)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .accessibilityIdentifier("setEditorDurationField")
                        }
                    } else {
                        HStack {
                            Text("Weight (kg)")
                            Spacer()
                            TextField("0", text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .accessibilityIdentifier("setEditorWeightField")
                                .onChange(of: weight) { _, newValue in
                                    weight = newValue.replacingOccurrences(of: ",", with: ".")
                                }
                        }
                        HStack {
                            Text("Reps")
                            Spacer()
                            TextField("0", text: $reps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .accessibilityIdentifier("setEditorRepsField")
                        }
                    }
                }

                Section {
                    DatePicker("Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    if isTimeOutOfRange {
                        Text("This time is outside the workout's time range.")
                            .foregroundStyle(Theme.Colors.warning)
                    }
                }

                if isEditMode {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Set")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Set" : "Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Delete Set?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Set", role: .destructive) {
                    deleteSet()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This set will be permanently removed. If it is the exercise's only set in this workout, the exercise will count as skipped.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isDurationField: Bool {
        switch mode {
        case .edit(let set):
            return set.duration != nil
        case .add(let exercise, _, _, _, _, _):
            return !exercise.hasTarget
        }
    }

    private var session: WorkoutSession? {
        switch mode {
        case .edit(let set):
            return set.session
        case .add(_, let session, _, _, _, _):
            return session
        }
    }

    private var parsedWeight: Double? {
        Double(weight.replacingOccurrences(of: ",", with: "."))
    }

    private var isTimeOutOfRange: Bool {
        guard let session else { return false }
        if startTime < session.startTime { return true }
        if let end = session.endTime, startTime > end { return true }
        return false
    }

    private var canSave: Bool {
        if isDurationField {
            return (Int(duration) ?? 0) > 0
        } else {
            return (parsedWeight ?? 0) > 0 && (Int(reps) ?? 0) > 0
        }
    }

    private func save() {
        let weightValue = isDurationField ? nil : parsedWeight
        let repsValue = isDurationField ? nil : Int(reps)
        let durationValue = isDurationField ? Int(duration) : nil

        switch mode {
        case .edit(let set):
            WorkoutPersistence.updateSet(
                set,
                weight: weightValue,
                reps: repsValue,
                duration: durationValue,
                startTime: startTime,
                in: modelContext
            )
        case .add(let exercise, let session, _, _, _, _):
            WorkoutPersistence.addSet(
                exercise: exercise,
                session: session,
                weight: weightValue,
                reps: repsValue,
                duration: durationValue,
                startTime: startTime,
                in: modelContext
            )
        }

        onSave?()
        dismiss()
    }

    private func deleteSet() {
        if case .edit(let set) = mode {
            WorkoutPersistence.deleteSet(set, in: modelContext)
        }
        onSave?()
        dismiss()
    }
}

struct AddExerciseToWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession
    var onPicked: (Exercise) -> Void

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if !skippedExercises.isEmpty {
                    Section("Skipped in This Workout") {
                        ForEach(skippedExercises) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }

                Section("All Exercises") {
                    ForEach(otherExercises) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
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

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            onPicked(exercise)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let target = exercise.targetString {
                        Text(target)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let categoryName = exercise.category?.name {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(.blue.opacity(0.12), in: Capsule())
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .frame(minHeight: Theme.TouchTarget.minimum)
        }
    }

    private func matchesSearch(_ exercise: Exercise) -> Bool {
        searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
    }

    private var performedExerciseIds: Set<UUID> {
        Set((session.sets ?? []).compactMap { $0.exercise?.id })
    }

    private var skippedIds: Set<UUID> {
        guard let ids = session.skippedExerciseIds,
              let splitExercises = session.split?.exercises
        else {
            return []
        }
        let requested = Set(ids)
        return Set(splitExercises.filter { requested.contains($0.id) }.map { $0.id })
    }

    private var skippedExercises: [Exercise] {
        guard let splitExercises = session.split?.exercises else { return [] }
        return splitExercises
            .filter { skippedIds.contains($0.id) }
            .filter { matchesSearch($0) }
            .sorted { $0.name < $1.name }
    }

    private var otherExercises: [Exercise] {
        exercises.filter {
            !performedExerciseIds.contains($0.id) &&
            !skippedIds.contains($0.id) &&
            matchesSearch($0)
        }
    }
}

struct SessionTimeEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    @State private var startTime: Date
    @State private var endTime: Date
    private let hasEndTime: Bool

    init(session: WorkoutSession) {
        self.session = session
        _startTime = State(initialValue: session.startTime)
        _endTime = State(initialValue: session.endTime ?? session.startTime)
        hasEndTime = session.endTime != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])

                    if hasEndTime {
                        DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])

                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(durationString)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var canSave: Bool {
        !hasEndTime || startTime < endTime
    }

    private var durationString: String {
        let total = Int(endTime.timeIntervalSince(startTime))
        guard total > 0 else { return "0m" }
        let hours = total / 3600
        let minutes = (total / 60) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func save() {
        WorkoutPersistence.updateSessionTimes(
            session,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            in: modelContext
        )
        dismiss()
    }
}
