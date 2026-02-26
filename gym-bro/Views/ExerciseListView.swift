//
//  ExerciseListView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var isPresentingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(exercises) { exercise in
                    NavigationLink {
                        ExerciseFormView(exercise: exercise)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .font(.headline)

                            if let categoryName = exercise.category?.name {
                                Text(categoryName)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }

                            Text(exercise.splitNames ?? "No splits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
            }
            .navigationTitle("Exercises")
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

    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(exercises[index])
            }
        }
    }
}

struct ExerciseFormView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \ExerciseCategory.name) private var categories: [ExerciseCategory]

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

    var isEditing: Bool {
        exercise != nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Exercise name", text: $name)
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
                    }
                }
            }
            
            Section("Rest Timer") {
                Toggle("Override default rest timer", isOn: $hasRestTimerOverride)
                
                if hasRestTimerOverride {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Slider(
                                value: $restTimerOverride,
                                in: 30...600,
                                step: 15
                            )
                            
                            Text("\(Int(restTimerOverride))s")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 50)
                        }
                        
                        Text("Rest timer duration for this exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
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
    }

    private func save() {
        if let exercise = exercise {
            // Update existing
            exercise.name = name
            exercise.notes = !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? notes : nil
            exercise.category = selectedCategory
            exercise.targetWeight = hasTarget ? targetWeight : nil
            exercise.targetSets = hasTarget ? targetSets : nil
            exercise.minReps = hasTarget ? minReps : nil
            exercise.maxReps = hasTarget ? maxReps : nil
            exercise.restTimerDurationOverride = hasRestTimerOverride ? restTimerOverride : nil
        } else {
            // Create new
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
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    ExerciseListView()
    //AddExerciseSheet()
}
