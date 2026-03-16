//
//  WorkoutSyncMessage.swift
//  gym-bro
//

import Foundation

struct WorkoutSyncMessage: Codable {
    enum MessageType: String, Codable {
        case workoutStarted
        case workoutEnded
        case setLogged
        case exerciseChanged
        case timerStarted
        case timerStopped
        case timerExpired
        case requestSync
        case splitData
        case settingsSync
    }

    var type: MessageType
    var sessionId: UUID?
    var exerciseId: UUID?
    var splitId: UUID?
    var locationId: UUID?
    var weight: Double?
    var reps: Int?
    var duration: Int?
    var setNumber: Int?
    var exerciseIndex: Int?
    var timerDuration: TimeInterval?
    var timestamp: Date?

    init(type: MessageType) {
        self.type = type
        self.timestamp = Date()
    }

    // MARK: - Dictionary Conversion (for WCSession messaging)

    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["type": type.rawValue]
        }
        return dict
    }

    static func from(dictionary: [String: Any]) -> WorkoutSyncMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return nil
        }
        return try? JSONDecoder().decode(WorkoutSyncMessage.self, from: data)
    }
}
