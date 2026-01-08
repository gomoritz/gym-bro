//
//  SampleData.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftData
import SwiftUI

struct SampleData: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let schema = Schema([
            Exercise.self, Split.self, WorkoutSession.self, WorkoutSet.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        
        Exercise.sampleData.forEach { container.mainContext.insert($0) }
        Split.sampleData.forEach { container.mainContext.insert($0) }
        WorkoutSession.sampleData.forEach { container.mainContext.insert($0) }
        WorkoutSet.sampleData.forEach { container.mainContext.insert($0) }

        return container
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleData: Self = .modifier(SampleData())
}
