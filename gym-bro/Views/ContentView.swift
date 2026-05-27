//
//  ContentView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 08.01.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Splits", systemImage: "list.bullet.clipboard") {
                SplitListView()
            }

            Tab("Exercises", systemImage: "dumbbell.fill") {
                ExerciseListView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath") {
                WorkoutHistoryView()
            }

            Tab("Stats", systemImage: "chart.xyaxis.line") {
                StatisticsView()
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
