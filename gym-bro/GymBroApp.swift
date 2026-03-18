//
//  GymBroApp.swift
//  gym-bro
//
//  Created by Moritz Goessl on 08.01.26.
//

import SwiftData
import SwiftUI
import WatchConnectivity

@main
struct GymBroApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self, Split.self, WorkoutSession.self, WorkoutSet.self,
            ExerciseCategory.self, GymLocation.self, ExerciseLocationProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @Environment(\.scenePhase) var scenePhase
    @State private var sessionManager = SessionManager()
    @State private var settings = Settings()
    @State private var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
                .environment(settings)
                .environment(connectivityManager)
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    sessionManager.configure(settings: settings, connectivityManager: connectivityManager)
                    connectivityManager.configure(modelContext: context)
                    syncSplitsToWatch(context: context)
                    Task { @MainActor in
                        WorkoutLiveActivityManager.shared.requestNotificationAuthorization()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in
                    sessionManager.acknowledgeTimerExpiry()
                    // Re-sync splits whenever app becomes active
                    syncSplitsToWatch(context: sharedModelContainer.mainContext)
                }
            }
        }
    }

    private func syncSplitsToWatch(context: ModelContext) {
        do {
            let splits = try context.fetch(FetchDescriptor<Split>(sortBy: [SortDescriptor(\Split.name)]))
            let locations = try context.fetch(FetchDescriptor<GymLocation>(sortBy: [SortDescriptor(\GymLocation.sortOrder)]))
            let categories = try context.fetch(FetchDescriptor<ExerciseCategory>(sortBy: [SortDescriptor(\ExerciseCategory.name)]))
            connectivityManager.syncSplitsToWatch(splits: splits, locations: locations, categories: categories)
        } catch {
            print("[WatchSync] Failed to fetch data for sync: \(error)")
        }
    }
}
