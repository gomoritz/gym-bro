//
//  ProgressionSampleData.swift
//  gym-bro
//

import Foundation
import SwiftData

@MainActor
enum ProgressionPreviewData {
    struct Fixture {
        let container: ModelContainer
        let exercise: Exercise
        let location: GymLocation
    }

    static func make() -> Fixture {
        let schema = Schema([
            Exercise.self, Split.self, WorkoutSession.self, WorkoutSet.self,
            ExerciseCategory.self, GymLocation.self, ExerciseLocationProfile.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let location = GymLocation(name: "FIT STAR Sportsclub Lauf", sortOrder: 0)
        let exercise = Exercise(
            name: "Chest Press",
            notes: "Brust anspannen",
            targetWeight: 30,
            targetSets: 4,
            minReps: 8,
            maxReps: 12
        )
        context.insert(location)
        context.insert(exercise)

        // Weight held at the 30 kg target throughout. e1RM climbs via extra reps in
        // earlier sessions (Trigger B), and the latest session maxes all four sets at
        // the top of the rep range (Trigger A).
        let plan: [(days: Int, reps: Int)] = [
            (-21, 10),
            (-14, 13),
            (-7, 14),
            (-1, 12),
        ]

        for entry in plan {
            let base = Calendar.current.date(byAdding: .day, value: entry.days, to: Date())!
            let session = WorkoutSession(
                startTime: base,
                endTime: Calendar.current.date(byAdding: .hour, value: 1, to: base)!,
                gymLocation: location
            )
            context.insert(session)

            for setIndex in 0..<4 {
                let setStart = Calendar.current.date(byAdding: .minute, value: setIndex * 5, to: base)!
                let set = WorkoutSet(
                    startTime: setStart,
                    weight: 30,
                    reps: entry.reps,
                    exercise: exercise,
                    session: session
                )
                context.insert(set)
            }
        }

        return Fixture(container: container, exercise: exercise, location: location)
    }
}

extension ProgressionSuggestion {
    static var sampleSuggestion: ProgressionSuggestion {
        ProgressionSuggestion(
            triggers: [
                .repMaxReached(sessionDate: .now, completedSets: 4, targetSets: 4, reps: 12, weight: 30),
                .e1rmTrend(bestRecentE1RM: 44, impliedE1RM: 42, sessionsConsidered: 3),
            ],
            suggestedWeight: 35,
            basis: ProgressionBasis(
                gymScoped: true,
                locationName: "FIT STAR Sportsclub Lauf",
                currentTargetWeight: 30,
                impliedE1RM: 42,
                bestRecentE1RM: 44,
                sessionsConsidered: 3,
                mostRecentSessionDate: .now
            )
        )
    }
}
