//
//  SyncSettingsView.swift
//  DariApp
//
//  Einstellungen für den Abgleich mit dem eigenen Server (NUC, „ZARA-Sync").
//

import SwiftUI
import SwiftData

struct SyncSettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @State private var sync = SyncService.shared
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                TextField("Server, z. B. http://10.0.0.201:8090", text: $sync.serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Schlüssel", text: $sync.accessKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("Abgleich eingeschaltet", isOn: $sync.enabled)
            } header: {
                Text("Server")
            } footer: {
                Text("Der Server bewahrt jeden Stand auf und löscht nie etwas. Beim Abgleich werden Daten zusammengeführt – auf diesem Gerät geht nichts verloren. Sprachaufnahmen bleiben auf dem Gerät.")
            }

            Section("Status") {
                LabeledContent("Zuletzt abgeglichen", value: sync.lastOkAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "noch nie")
                if let error = sync.lastError {
                    Text(error).foregroundStyle(.red).font(DariFont.caption)
                }
                Button {
                    Task {
                        let merged = await sync.pull(context: context, settings: settings)
                        if !merged { await sync.push(context: context, settings: settings) }
                        message = sync.lastError == nil ? "Abgeglichen ✓" : nil
                    }
                } label: {
                    if sync.busy { ProgressView() } else { Text("Jetzt abgleichen") }
                }
                .disabled(!sync.isReady || sync.busy)
                if let message { Text(message).foregroundStyle(Palette.textSecondary) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Server-Abgleich")
    }
}
