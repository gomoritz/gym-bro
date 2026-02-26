//
//  SettingsView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 13.01.26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Rest Timer") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Rest Duration")
                            .font(.headline)

                        HStack {
                            Slider(
                                value: $settings.defaultRestTimerDuration,
                                in: Constants.Timer.restDurationRange,
                                step: Constants.Timer.restDurationStep
                            )
                            .tint(.blue)

                            Text("\(Int(settings.defaultRestTimerDuration))s")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                                .frame(width: 50)
                        }

                        Text("Default rest period between sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.sm)

                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Transition Duration")
                            .font(.headline)

                        HStack {
                            Slider(
                                value: $settings.defaultTransitionTimerDuration,
                                in: Constants.Timer.transitionDurationRange,
                                step: Constants.Timer.transitionDurationStep
                            )
                            .tint(.blue)

                            Text("\(Int(settings.defaultTransitionTimerDuration))s")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                                .frame(width: 50)
                        }

                        Text("Default time to prepare for next exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }

                Section("Info") {
                    Text("Rest timer duration can be customized per exercise in the exercise settings. Transition timer is always set to the default duration above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environment(Settings())
}
