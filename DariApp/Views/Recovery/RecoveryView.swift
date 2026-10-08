//
//  RecoveryView.swift
//  DariApp
//
//  Wird angezeigt, wenn die Datenbank nicht geoeffnet werden konnte. Statt
//  eines Absturzes bekommt der Nutzer klare Optionen. Es wird nichts geloescht:
//  Schnappschuesse werden zurueckgespielt, defekte Dateien nur beiseitegelegt.
//

import SwiftUI

struct RecoveryView: View {

    let issue: String
    let storeURL: URL

    private let safety = StoreSafety()
    @State private var snapshots: [StoreSnapshotInfo] = []
    @State private var pendingRestore: StoreSnapshotInfo?
    @State private var confirmFresh = false
    @State private var finished: String?
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 54))
                    .foregroundStyle(Palette.terracotta)
                Text("Deine Daten brauchen Aufmerksamkeit")
                    .font(DariFont.title)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textPrimary)
                Text("ZARA konnte die gespeicherten Daten nicht öffnen. Es wurde nichts gelöscht oder überschrieben.")
                    .font(DariFont.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                Text(issue)
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)

                if let finished {
                    CardSurface {
                        VStack(spacing: Spacing.xs) {
                            Label("Erledigt", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Palette.success)
                                .font(DariFont.headline)
                            Text(finished)
                                .font(DariFont.body)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    snapshotSection
                    Button(role: .destructive) { confirmFresh = true } label: {
                        Text("Neu beginnen (Daten bleiben als Kopie erhalten)")
                    }
                    .buttonStyle(.bordered)
                }
                if let errorText {
                    Text(errorText).font(DariFont.caption).foregroundStyle(Palette.error)
                }
            }
            .padding(Spacing.lg)
        }
        .background(Palette.background)
        .task { snapshots = safety.listSnapshots().filter { $0.reason != "replaced" } }
        .alert("Sicherung wiederherstellen?", isPresented: Binding(
            get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })
        ) {
            Button("Wiederherstellen") { if let s = pendingRestore { restore(s) } }
            Button("Abbrechen", role: .cancel) { pendingRestore = nil }
        } message: {
            if let s = pendingRestore {
                Text("Stand vom \(s.date.formatted(date: .abbreviated, time: .shortened)). Die aktuellen Dateien werden vorher beiseitegelegt.")
            }
        }
        .alert("Wirklich neu beginnen?", isPresented: $confirmFresh) {
            Button("Neu beginnen", role: .destructive) { startFresh() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("ZARA startet leer. Die bisherigen Dateien bleiben als Sicherungskopie auf dem Gerät.")
        }
    }

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Automatische Sicherungen")
                .font(DariFont.headline)
                .foregroundStyle(Palette.textPrimary)
            if snapshots.isEmpty {
                Text("Keine Sicherungen gefunden. Du kannst später ein Backup aus „Dateien“ einspielen (Mehr → Backup).")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(snapshots) { snap in
                    CardSurface(padding: Spacing.sm) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(DariFont.body)
                                Text(snap.reasonTitle)
                                    .font(DariFont.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            Spacer()
                            Button("Laden") { pendingRestore = snap }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func restore(_ snapshot: StoreSnapshotInfo) {
        do {
            try safety.restore(snapshot, to: storeURL)
            finished = "Die Sicherung wurde zurückgespielt. Bitte ZARA jetzt schließen (nach oben wischen) und neu öffnen."
        } catch {
            errorText = "Wiederherstellung nicht möglich: \(error.localizedDescription)"
        }
        pendingRestore = nil
    }

    private func startFresh() {
        do {
            try safety.moveAside(storeURL: storeURL)
            finished = "Die alten Dateien liegen sicher in der Sicherung. Bitte ZARA jetzt schließen (nach oben wischen) und neu öffnen."
        } catch {
            errorText = "Nicht möglich: \(error.localizedDescription)"
        }
    }
}
