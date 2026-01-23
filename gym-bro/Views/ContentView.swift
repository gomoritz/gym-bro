//
//  ContentView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SplitListView()
                .tabItem {
                    Label("Splits", systemImage: "list.bullet.clipboard")
                }
            
            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell.fill")
                }

            WorkoutHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
