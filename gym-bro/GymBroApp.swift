//
//  GymBroApp.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftData
import SwiftUI

@main
struct GymBroApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self, Split.self, WorkoutSession.self, WorkoutSet.self,
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Check if timer expired while in background
                Task { @MainActor in
                    RestTimerActivityManager.shared.checkExpiration()
                    
                    // Clear expired Live Activity when entering app
                    if RestTimerActivityManager.shared.isExpired {
                        RestTimerActivityManager.shared.endActivity()
                    }
                }
            }
        }
    }
}
