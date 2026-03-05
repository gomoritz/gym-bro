//
//  GymLocationListView.swift
//  gym-bro
//

import SwiftData
import SwiftUI

struct GymLocationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymLocation.sortOrder) private var locations: [GymLocation]

    @State private var isAddingLocation = false
    @State private var newLocationName = ""
    @State private var editingLocation: GymLocation?
    @State private var editName = ""

    var body: some View {
        List {
            if locations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "building.2",
                    description: Text("Add your gym locations to track exercise settings per location.")
                )
            } else {
                ForEach(locations) { location in
                    Button {
                        editingLocation = location
                        editName = location.name
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(location.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                let profileCount = location.exerciseProfiles?.count ?? 0
                                if profileCount > 0 {
                                    Text("\(profileCount) exercise profile\(profileCount > 1 ? "s" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                .onDelete(perform: deleteLocations)
                .onMove(perform: moveLocations)
            }
        }
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !locations.isEmpty {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") {
                    newLocationName = ""
                    isAddingLocation = true
                }
            }
        }
        .alert("New Location", isPresented: $isAddingLocation) {
            TextField("Location name", text: $newLocationName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                addLocation()
            }
        }
        .alert("Edit Location", isPresented: Binding(
            get: { editingLocation != nil },
            set: { if !$0 { editingLocation = nil } }
        )) {
            TextField("Location name", text: $editName)
            Button("Cancel", role: .cancel) {
                editingLocation = nil
            }
            Button("Save") {
                if let location = editingLocation {
                    let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        location.name = trimmed
                    }
                }
                editingLocation = nil
            }
        }
    }

    private func addLocation() {
        let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let location = GymLocation(name: trimmed, sortOrder: locations.count)
        modelContext.insert(location)
    }

    private func deleteLocations(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(locations[index])
        }
    }

    private func moveLocations(from source: IndexSet, to destination: Int) {
        var reordered = locations
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, location) in reordered.enumerated() {
            location.sortOrder = index
        }
    }
}
