//
//  SplitListView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 08.01.26.
//

import SwiftData
import SwiftUI

struct SplitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Split.name) private var splits: [Split]

    @State private var isPresentingAddAlert = false
    @State private var newSplitName = ""

    var body: some View {
        NavigationStack {
            Group {
                if splits.isEmpty {
                    emptyStateView
                } else {
                    splitList
                }
            }
            .navigationTitle("Splits")
            .toolbar {
                Button("Add", systemImage: "plus") {
                    isPresentingAddAlert = true
                }
            }
            .alert("Create a new split", isPresented: $isPresentingAddAlert) {
                TextField("Name", text: $newSplitName)
                Button("Add") {
                    let newSplit = Split(name: newSplitName)
                    modelContext.insert(newSplit)
                    newSplitName = ""
                }
                Button("Cancel", role: .cancel) {
                    newSplitName = ""
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 70))
                .foregroundStyle(.tertiary)

            Text("No Splits Yet")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Text("Create a split to organize your workouts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var splitList: some View {
        List {
            ForEach(splits) { split in
                NavigationLink {
                    SplitDetailView(split: split)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(split.name)
                                .font(.headline)

                            if let exercises = split.exercises, !exercises.isEmpty {
                                Text("\(exercises.count) exercise\(exercises.count > 1 ? "s" : "")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No exercises")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        if let count = split.exercises?.count, count > 0 {
                            Text("\(count)")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(.blue.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .onDelete(perform: deleteSplit)
        }
    }

    private func deleteSplit(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(splits[index])
        }
    }
}

#Preview(traits: .sampleData) {
    SplitListView()
}
