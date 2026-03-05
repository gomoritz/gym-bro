//
//  GymBroApp.swift
//  gym-bro
//
//  Created by Moritz Goessl on 08.01.26.
//

import SwiftData
import SwiftUI

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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
                .environment(settings)
                .onAppear {
                    sessionManager.configure(settings: settings)
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
                }
            }
        }
    }
}
