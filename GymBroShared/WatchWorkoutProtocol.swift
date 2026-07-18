import Foundation

enum WatchTimerKind: String, Codable, Sendable {
    case rest
    case transition
}

struct WatchExerciseSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let targetWeight: Double?
    let targetSets: Int?
    let minReps: Int?
    let maxReps: Int?
    let notes: String?
}

struct WatchWorkoutSnapshot: Codable, Equatable, Sendable {
    let revision: Int
    let sessionID: UUID?
    let splitName: String?
    let currentExercise: WatchExerciseSnapshot?
    let remainingExercises: [WatchExerciseSnapshot]
    let currentSetNumber: Int
    let suggestedWeight: Double?
    let suggestedReps: Int?
    let timerKind: WatchTimerKind?
    let timerEndDate: Date?
    let timerDuration: TimeInterval?
    let timerExpired: Bool
    let isWorkoutActive: Bool

    static let idle = WatchWorkoutSnapshot(
        revision: 0,
        sessionID: nil,
        splitName: nil,
        currentExercise: nil,
        remainingExercises: [],
        currentSetNumber: 1,
        suggestedWeight: nil,
        suggestedReps: nil,
        timerKind: nil,
        timerEndDate: nil,
        timerDuration: nil,
        timerExpired: false,
        isWorkoutActive: false
    )
}

enum WatchWorkoutCommand: Codable, Equatable, Sendable {
    case logSet(weight: Double, reps: Int)
    case selectExercise(id: UUID)
    case stopTimer
    case acknowledgeTimer
    case endWorkout
}

enum WatchWorkoutMessage {
    nonisolated static let snapshotKey = "workoutSnapshot"
    nonisolated static let commandKey = "workoutCommand"
    nonisolated static let requestSnapshotKey = "requestWorkoutSnapshot"

    nonisolated static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    nonisolated static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
