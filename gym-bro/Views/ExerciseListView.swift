//
//  ExerciseListView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 08.01.26.
//

import SwiftData
import SwiftUI
import os

private let logger = Logger(subsystem: "com.gym-bro", category: "ExerciseListView")

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<WorkoutSession> { $0.endTime == nil })
    private var activeSessions: [WorkoutSession]

    @State private var isPresentingAddSheet = false
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var activeExerciseIDs: Set<UUID> {
        Set(activeSessions.flatMap { $0.split?.exercises ?? [] }.map { $0.id })
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    emptyStateView
                } else {
                    exerciseList
                }
            }
            .navigationTitle("Exercises")
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                Button("Add", systemImage: "plus") {
                    isPresentingAddSheet = true
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                NavigationStack {
                    ExerciseFormView()
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 70))
                .foregroundStyle(.tertiary)

            Text("No Exercises Yet")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Text("Add exercises to build your workout library")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var exerciseList: some View {
        List {
            ForEach(filteredExercises) { exercise in
                NavigationLink {
                    ExerciseFormView(exercise: exercise)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(exercise.name)
                                .font(.headline)

                            if let target = exercise.targetString {
                                Text(target)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let splitNames = exercise.splitNames {
                                Text(splitNames)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
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
                }
                .swipeActions(edge: .trailing) {
                    if !activeExerciseIDs.contains(exercise.id) {
                        Button(role: .destructive) {
                            withAnimation {
                                modelContext.delete(exercise)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

}

struct ExerciseFormView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \ExerciseCategory.name) private var categories: [ExerciseCategory]
    @Query(sort: \GymLocation.sortOrder) private var locations: [GymLocation]

    var exercise: Exercise?

    @State private var name = ""
    @State private var notes = ""
    @State private var selectedCategory: ExerciseCategory?

    @State private var hasTarget = true
    @State private var targetSets = 4
    @State private var targetWeight = 10.0
    @State private var minReps = 8
    @State private var maxReps = 12

    @State private var hasRestTimerOverride = false
    @State private var restTimerOverride: TimeInterval = 120

    @State private var isAddingCategory = false
    @State private var newCategoryName = ""

    @State private var editingProfile: ExerciseLocationProfile?
    @State private var profileWeight = ""
    @State private var profileNotes = ""

    var isEditing: Bool {
        exercise != nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Exercise name", text: $name)
                    .font(.headline)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...)
                Toggle("Set target", isOn: $hasTarget)
            }

            Section("Category") {
                Picker("Category", selection: $selectedCategory) {
                    Text("None")
                        .tag(nil as ExerciseCategory?)
                    ForEach(categories) { category in
                        Text(category.name)
                            .tag(category as ExerciseCategory?)
                    }
                }

                Button("New Category") {
                    isAddingCategory = true
                }
            }

            if hasTarget {
                Section("Target") {
                    Stepper(
                        "**\(targetSets) sets**",
                        value: $targetSets,
                        in: 1...8
                    )
                    Stepper(
                        "**\(minReps) reps** minimum",
                        value: $minReps,
                        in: 1...maxReps
                    )
                    Stepper(
                        "**\(maxReps) reps** maximum",
                        value: $maxReps,
                        in: minReps...100
                    )

                    VStack {
                        Stepper(
                            "**\(String(format: "%.1f", targetWeight)) kg** weight",
                            value: $targetWeight,
                            in: 1.0...200.0,
                            step: 0.5
                        )

                        Slider(value: $targetWeight, in: 1...200, step: 0.5)
                            .tint(.blue)
                    }
                }
            }

            if isEditing && !locations.isEmpty {
                Section("Location Profiles") {
                    if let profiles = exercise?.locationProfiles, !profiles.isEmpty {
                        ForEach(profiles) { profile in
                            Button {
                                editingProfile = profile
                                profileWeight = profile.targetWeight.map { String(format: "%.1f", $0) } ?? ""
                                profileNotes = profile.notes ?? ""
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        Text(profile.location?.name ?? "Unknown")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        HStack(spacing: Theme.Spacing.sm) {
                                            if let w = profile.targetWeight {
                                                Text("\(String(format: "%.1f", w))kg")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let n = profile.notes, !n.isEmpty {
                                                Text(n)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    let existingLocationIds = Set((exercise?.locationProfiles ?? []).compactMap { $0.location?.id })
                    let unlinkedLocations = locations.filter { !existingLocationIds.contains($0.id) }

                    if !unlinkedLocations.isEmpty {
                        Menu {
                            ForEach(unlinkedLocations) { location in
                                Button(location.name) {
                                    addProfile(for: location)
                                }
                            }
                        } label: {
                            Label("Add Location Profile", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            Section("Rest Timer") {
                Toggle("Override default rest timer", isOn: $hasRestTimerOverride)

                if hasRestTimerOverride {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Slider(
                                value: $restTimerOverride,
                                in: Constants.Timer.restDurationRange,
                                step: Constants.Timer.restDurationStep
                            )
                            .tint(.blue)

                            Text("\(Int(restTimerOverride))s")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                                .frame(width: 50)
                        }

                        Text("Rest timer duration for this exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
        .toolbar {
            Button("Save") {
                save()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onAppear {
            if let exercise = exercise {
                name = exercise.name
                notes = exercise.notes ?? ""
                selectedCategory = exercise.category
                hasTarget = exercise.hasTarget
                targetWeight = exercise.targetWeight ?? 10.0
                targetSets = exercise.targetSets ?? 4
                minReps = exercise.minReps ?? 8
                maxReps = exercise.maxReps ?? 12

                if let override = exercise.restTimerDurationOverride {
                    hasRestTimerOverride = true
                    restTimerOverride = override
                }
            }
        }
        .alert("New Category", isPresented: $isAddingCategory) {
            TextField("Category name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Add") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let category = ExerciseCategory(name: trimmed)
                    modelContext.insert(category)
                    selectedCategory = category
                }
                newCategoryName = ""
            }
        }
        .alert("Edit Profile – \(editingProfile?.location?.name ?? "")", isPresented: Binding(
            get: { editingProfile != nil },
            set: { if !$0 { editingProfile = nil } }
        )) {
            TextField("Weight (kg)", text: $profileWeight)
                .keyboardType(.decimalPad)
            TextField("Notes", text: $profileNotes)
            Button("Cancel", role: .cancel) {
                editingProfile = nil
            }
            Button("Save") {
                if let profile = editingProfile {
                    profile.targetWeight = Double(profileWeight.replacingOccurrences(of: ",", with: "."))
                    let trimmedNotes = profileNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
                }
                editingProfile = nil
            }
        }
    }

    private func addProfile(for location: GymLocation) {
        guard let exercise else { return }
        let profile = WorkoutPersistence.findOrCreateProfile(
            exercise: exercise, location: location, in: modelContext
        )
        profile.targetWeight = hasTarget ? targetWeight : nil
    }

    private func save() {
        if let exercise = exercise {
            exercise.name = name
            exercise.notes = !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? notes : nil
            exercise.category = selectedCategory
            exercise.targetWeight = hasTarget ? targetWeight : nil
            exercise.targetSets = hasTarget ? targetSets : nil
            exercise.minReps = hasTarget ? minReps : nil
            exercise.maxReps = hasTarget ? maxReps : nil
            exercise.restTimerDurationOverride = hasRestTimerOverride ? restTimerOverride : nil
        } else {
            let newExercise = Exercise(
                name: name,
                notes: !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? notes : nil,
                targetWeight: hasTarget ? targetWeight : nil,
                targetSets: hasTarget ? targetSets : nil,
                minReps: hasTarget ? minReps : nil,
                maxReps: hasTarget ? maxReps : nil,
                restTimerDurationOverride: hasRestTimerOverride ? restTimerOverride : nil
            )
            newExercise.category = selectedCategory
            modelContext.insert(newExercise)
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save exercise: \(error.localizedDescription)")
        }
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    ExerciseListView()
}
