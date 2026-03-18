//
//  SplitSyncData.swift
//  gym-bro
//

import Foundation

// MARK: - Transfer Data Structures

struct SplitSyncPayload: Codable {
    var splits: [SplitTransferData]
    var locations: [LocationTransferData]
    var categories: [CategoryTransferData]
}

struct SplitTransferData: Codable {
    var id: UUID
    var name: String
    var exerciseIds: [UUID]
}

struct ExerciseTransferData: Codable {
    var id: UUID
    var name: String
    var notes: String?
    var targetWeight: Double?
    var targetSets: Int?
    var minReps: Int?
    var maxReps: Int?
    var restTimerDurationOverride: TimeInterval?
    var categoryId: UUID?
    var locationProfiles: [LocationProfileTransferData]
}

struct LocationProfileTransferData: Codable {
    var id: UUID
    var locationId: UUID
    var targetWeight: Double?
    var notes: String?
}

struct LocationTransferData: Codable {
    var id: UUID
    var name: String
    var sortOrder: Int
}

struct CategoryTransferData: Codable {
    var id: UUID
    var name: String
}

// MARK: - Application Context Keys

enum SyncContextKey {
    static let splitSyncPayload = "splitSyncPayload"
    static let exercises = "exercises"
}
