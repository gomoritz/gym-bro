//
//  SettingsView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 13.01.26.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = Settings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Timer Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rest Timer Duration")
                            .font(.headline)
                        
                        HStack {
                            Slider(
                                value: $settings.defaultRestTimerDuration,
                                in: 30...600,
                                step: 15
                            )
                            
                            Text("\(Int(settings.defaultRestTimerDuration))s")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 50)
                        }
                        
                        Text("Default rest period between sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transition Timer Duration")
                            .font(.headline)
                        
                        HStack {
                            Slider(
                                value: $settings.defaultTransitionTimerDuration,
                                in: 15...300,
                                step: 15
                            )
                            
                            Text("\(Int(settings.defaultTransitionTimerDuration))s")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 50)
                        }
                        
                        Text("Default time to prepare for next exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Info") {
                    Text("Rest timer duration can be customized per exercise in the exercise settings. Transition timer is always set to the default duration above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
