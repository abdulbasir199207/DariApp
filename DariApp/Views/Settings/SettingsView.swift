//
//  SettingsView.swift
//  DariApp
//
//  Einstellungen: Erscheinungsbild, Standard-Lernmodus, Standard-Richtung,
//  taegliches Lernziel, Animationen. Bindet direkt an `AppSettings`.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Darstellung") {
                Picker("Erscheinungsbild", selection: $settings.appearance) {
                    ForEach(AppearancePreference.allCases) { pref in
                        Text(pref.title).tag(pref)
                    }
                }
                Toggle("Animationen", isOn: $settings.animationsEnabled)
            }

            Section("Lernen") {
                Picker("Standard-Modus", selection: $settings.defaultMode) {
                    ForEach(LearningMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                Picker("Standard-Richtung", selection: $settings.defaultDirection) {
                    ForEach(QueryDirection.allCases) { dir in
                        Text(dir.title).tag(dir)
                    }
                }
                Stepper(value: $settings.dailyGoal, in: 5...200, step: 5) {
                    HStack {
                        Text("Taegliches Ziel")
                        Spacer()
                        Text("\(settings.dailyGoal) Karten")
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Section {
                LabeledContent("Version", value: appVersion)
            } footer: {
                Text("DariApp – vollstaendig offline. Alle Daten bleiben auf diesem Geraet.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Einstellungen")
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppSettings())
        .modelContainer(PreviewData.container)
}
