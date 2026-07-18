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

        #if DEBUG
        // When running the logic-test harness, back the app with a single
        // in-memory, CloudKit-free container so the tests have an isolated store
        // and we never create a second ModelContainer for the same types.
        if DebugTestFlags.runLogicTests {
            let testConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [testConfig])
        }
        #endif

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
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

    #if DEBUG
    // Guards the one-shot DEBUG harness hooks (logic tests / reset / seed) so a
    // re-appear of ContentView (tab switches, scene changes, ...) does not
    // re-run them and clobber state the tests themselves mutated.
    @State private var didRunDebugHooks = false
    #endif

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
                    #if DEBUG
                    if !didRunDebugHooks {
                        didRunDebugHooks = true
                        let container = sharedModelContainer
                        Task { @MainActor in
                            // Run off the SwiftUI view-update cycle: creating a
                            // ModelContainer inside dispatchActions traps.
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            if DebugTestFlags.runLogicTests {
                                DebugLogicTests.run(context: container.mainContext)
                            }
                            if DebugTestFlags.resetStore {
                                DebugSeed.reset(container.mainContext)
                            }
                            if DebugTestFlags.seedTestData {
                                DebugSeed.seed(into: container.mainContext)
                            }
                        }
                    }
                    #endif
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
