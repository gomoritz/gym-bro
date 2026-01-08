//
//  SplitListView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftData
import SwiftUI

struct SplitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Split.name) private var splits: [Split]

    @State private var isPresentingAddAlert = false
    @State private var newSplitName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(splits) { split in
                    NavigationLink {
                        SplitDetailView(split: split)
                    } label: {
                        Text(split.name)
                            .font(.headline)
                    }
                }
                .onDelete(perform: deleteSplit)
            }
            .navigationTitle("Splits")
            .toolbar {
                Button("Add", systemImage: "plus") {
                    isPresentingAddAlert = true
                }
            }
            .alert("Create a new split", isPresented: $isPresentingAddAlert) {
                TextField("Name", text: $newSplitName)
                Button("Add") {
                    let newSplit = Split(name: newSplitName)
                    modelContext.insert(newSplit)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private func deleteSplit(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(splits[index])
        }
    }
}

#Preview(traits: .sampleData) {
    SplitListView()
}
