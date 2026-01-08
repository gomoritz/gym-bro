//
//  GymBroApp.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftUI
import SwiftData

@main
struct GymBroApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            Split.self,
            WorkoutSession.self,
            WorkoutSet.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Text("Hello, world")
        }
        .modelContainer(sharedModelContainer)
    }
}
