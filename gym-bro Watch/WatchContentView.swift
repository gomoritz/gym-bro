//
//  WatchContentView.swift
//  gym-bro Watch
//

import SwiftData
import SwiftUI

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchSessionManager.self) private var sessionManager
    @Query(sort: \Split.name) private var splits: [Split]
    @Query(sort: \GymLocation.sortOrder) private var locations: [GymLocation]

    @State private var selectedLocation: GymLocation?
    @State private var showLocationPicker = false

    var body: some View {
        NavigationStack {
            if sessionManager.isSessionActive {
                WatchActiveWorkoutView()
            } else if splits.isEmpty {
                noDataView
            } else {
                splitListView
            }
        }
    }

    // MARK: - No Data

    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Open Gym Bro on iPhone to set up your splits")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Split List

    private var splitListView: some View {
        List {
            if !locations.isEmpty {
                Section {
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text(selectedLocation?.name ?? "No Location")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Start Workout") {
                ForEach(splits) { split in
                    Button {
                        sessionManager.startSession(
                            for: split,
                            location: selectedLocation,
                            context: modelContext
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(split.name)
                                .font(.headline)
                            if let exercises = split.exercises {
                                Text("\(exercises.count) exercises")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Gym Bro")
        .sheet(isPresented: $showLocationPicker) {
            List {
                Button("No Location") {
                    selectedLocation = nil
                    showLocationPicker = false
                }
                ForEach(locations) { location in
                    Button(location.name) {
                        selectedLocation = location
                        showLocationPicker = false
                    }
                }
            }
            .navigationTitle("Location")
        }
    }
}
