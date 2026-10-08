//
//  BackupView.swift
//  DariApp
//
//  Backup sichern, einspielen und automatische Sicherungen verwalten.
//  Vor jeder Wiederherstellung sichert ZARA den aktuellen Stand automatisch;
//  die Wiederherstellung laesst sich rueckgaengig machen.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    var offersUndo = false
}

struct BackupView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var cards: [Card]
    @AppStorage("zara.lastExternalBackup") private var lastBackup: Double = 0

    @State private var shareItem: ShareItem?
    @State private var includeAudio = true
    @State private var showImporter = false
    @State private var pending: ParsedBackup?
    @State private var pendingSource = ""
    @State private var message: AlertMessage?
    @State private var autoBackups: [JSONBackupInfo] = []
    @State private var undoURL: URL?

    private let safety = StoreSafety()

    private var hasAudio: Bool { cards.contains { $0.hasAudio } }

    var body: some View {
        Form {
            Section {
                LabeledContent("Karten", value: "\(cards.count)")
                LabeledContent("Letztes Backup", value: lastBackup == 0
                               ? "noch nie"
                               : Date(timeIntervalSince1970: lastBackup).formatted(date: .abbreviated, time: .shortened))
            } footer: {
                Text("Dein Fortschritt liegt nur auf diesem Gerät. Sichere regelmäßig ein Backup in „Dateien“ oder iCloud Drive.")
            }

            Section("Backup sichern") {
                if hasAudio { Toggle("Aufnahmen einschließen", isOn: $includeAudio) }
                Button {
                    exportBackup()
                } label: {
                    Label("Backup erstellen und sichern", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("backup.export")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Backup-Datei einspielen", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("backup.import")
            } header: {
                Text("Wiederherstellen")
            } footer: {
                Text("Auch Backups der ZARA-Web-App können eingespielt werden. Vorher sichert ZARA den aktuellen Stand automatisch.")
            }

            Section {
                if autoBackups.isEmpty {
                    Text("Noch keine automatische Sicherung.")
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    ForEach(autoBackups) { info in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(info.date.formatted(date: .abbreviated, time: .shortened))
                                Text(info.reason == "auto" ? "Automatisch (täglich)" : "Vor Wiederherstellung")
                                    .font(DariFont.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            Spacer()
                            Button("Laden") { load(info) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            } header: {
                Text("Automatische Sicherungen")
            } footer: {
                Text("ZARA sichert täglich und vor jeder Wiederherstellung (nur auf diesem Gerät). Zusätzlich wird die Datenbank vor jedem App-Update kopiert.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Daten & Backup")
        .navigationBarTitleDisplayMode(.inline)
        .task { autoBackups = safety.listJSONBackups() }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url) { completed in
                if completed { lastBackup = Date().timeIntervalSince1970 }
            }
            .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .data]) { result in
            switch result {
            case .success(let url): readFile(url)
            case .failure(let error): message = AlertMessage(title: "Datei nicht lesbar", text: error.localizedDescription)
            }
        }
        .confirmationDialog("Backup gefunden", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible, presenting: pending) { parsed in
            Button("Ersetzen", role: .destructive) { apply(parsed, mode: .replace) }
            Button("Zusammenführen") { apply(parsed, mode: .merge) }
            Button("Abbrechen", role: .cancel) { }
        } message: { parsed in
            Text(summaryText(parsed))
        }
        .alert(message?.title ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } }), presenting: message) { m in
            if m.offersUndo { Button("Rückgängig machen") { undo() } }
            Button("OK", role: .cancel) { }
        } message: { m in
            Text(m.text)
        }
    }

    // MARK: Export

    private func exportBackup() {
        do {
            let data = try BackupService(context: context, settings: settings)
                .makeBackup(includeAudio: includeAudio && hasAudio)
            let url = FileManager.default.temporaryDirectory.appending(path: BackupService.fileName())
            try data.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
        } catch {
            message = AlertMessage(title: "Backup nicht möglich", text: error.localizedDescription)
        }
    }

    // MARK: Import

    private func readFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            consider(data, source: url.lastPathComponent)
        } catch {
            message = AlertMessage(title: "Datei nicht lesbar", text: error.localizedDescription)
        }
    }

    private func load(_ info: JSONBackupInfo) {
        do { consider(try Data(contentsOf: info.url), source: info.url.lastPathComponent) }
        catch { message = AlertMessage(title: "Sicherung nicht lesbar", text: error.localizedDescription) }
    }

    private func consider(_ data: Data, source: String) {
        switch BackupService.parse(data) {
        case .success(let parsed): pendingSource = source; pending = parsed
        case .failure(let error): message = AlertMessage(title: "Backup nicht verwendbar", text: error.localizedDescription)
        }
    }

    private func summaryText(_ parsed: ParsedBackup) -> String {
        var lines = ["\(parsed.cardCount) Karten · \(parsed.logCount) Verlaufseinträge · \(parsed.tagCount) Tags"]
        if let created = parsed.createdAt { lines.append("Erstellt: \(created.formatted(date: .abbreviated, time: .shortened))") }
        if parsed.isLegacy { lines.append("Älteres Format – wird automatisch aktualisiert.") }
        lines.append("Aktuell auf diesem Gerät: \(cards.count) Karten.")
        lines.append("„Ersetzen“ überschreibt den aktuellen Stand (vorher wird er gesichert), „Zusammenführen“ behält alles.")
        return lines.joined(separator: "\n")
    }

    private func apply(_ parsed: ParsedBackup, mode: RestoreMode) {
        let service = BackupService(context: context, settings: settings)
        do {
            // Sicherheitskopie des aktuellen Standes – nur wenn es etwas zu sichern gibt.
            if !cards.isEmpty {
                undoURL = try safety.writeJSONBackup(try service.makeBackup(includeAudio: false), reason: "restore")
            } else { undoURL = nil }
            let summary = try service.apply(parsed, mode: mode)
            autoBackups = safety.listJSONBackups()
            let detail = mode == .merge ? " (\(summary.added) neu, \(summary.updated) aktualisiert)" : ""
            message = AlertMessage(
                title: "Wiederhergestellt",
                text: "\(summary.cards) Karten sind jetzt in ZARA\(detail).",
                offersUndo: undoURL != nil)
        } catch {
            message = AlertMessage(title: "Nicht wiederhergestellt",
                                   text: "Es wurde nichts verändert. (\(error.localizedDescription))")
        }
    }

    private func undo() {
        guard let url = undoURL, let data = try? Data(contentsOf: url) else { return }
        if case .success(let parsed) = BackupService.parse(data) {
            _ = try? BackupService(context: context, settings: settings).apply(parsed, mode: .replace)
            autoBackups = safety.listJSONBackups()
        }
        undoURL = nil
    }
}
