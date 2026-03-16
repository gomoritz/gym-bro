//
//  GymBroWatchApp.swift
//  gym-bro Watch
//

import SwiftData
import SwiftUI

@main
struct GymBroWatchApp: App {
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

    @State private var watchSessionManager = WatchSessionManager()
    @State private var settings = Settings()
    @State private var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(watchSessionManager)
                .environment(settings)
                .environment(connectivityManager)
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    watchSessionManager.configure(settings: settings, modelContext: context)
                    connectivityManager.configure(
                        sessionManager: watchSessionManager,
                        modelContext: context
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
