//
//  SettingsView.swift
//  DariApp
//
//  „Mehr": Erscheinungsbild, Standard-Modus/-Richtung, taegliches Lernziel,
//  Animationen, Vibration und der Bereich Daten & Backup.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @AppStorage("zara.lastExternalBackup") private var lastBackup: Double = 0

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
                Toggle("Vibration", isOn: $settings.hapticsEnabled)
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
                        Text("Tägliches Ziel")
                        Spacer()
                        Text("\(settings.dailyGoal) Karten")
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    BackupView()
                } label: {
                    HStack {
                        Label("Daten & Backup", systemImage: "externaldrive")
                        Spacer()
                        Text(lastBackup == 0 ? "noch kein Backup" : Date(timeIntervalSince1970: lastBackup).formatted(date: .abbreviated, time: .omitted))
                            .font(DariFont.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .accessibilityIdentifier("settings.backup")
            } footer: {
                Text("ZARA arbeitet vollständig offline. Alle Daten bleiben auf diesem Gerät – sichere sie regelmäßig als Backup.")
            }

            Section {
                LabeledContent("Version", value: appVersion)
            } footer: {
                Text("ZARA – Persisch und Deutsch lernen.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Mehr")
    }

    private var appVersion: String { BackupService.appVersionString }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppSettings())
        .modelContainer(PreviewData.container)
}
