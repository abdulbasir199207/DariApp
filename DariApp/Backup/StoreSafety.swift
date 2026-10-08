//
//  StoreSafety.swift
//  DariApp
//
//  Sicherungskopien der Datenbank, unabhaengig vom Store selbst:
//  - Schnappschuesse der SwiftData-Dateien (vor Updates/Wiederherstellungen/taeglich)
//  - taegliche JSON-Backups (lesbar, auch in der Web-Version importierbar)
//  Grundsatz: Es wird nie etwas geloescht, ohne dass eine Kopie existiert. Defekte
//  Stores werden nur „beiseitegelegt", nicht entfernt.
//

import Foundation

struct StoreSnapshotInfo: Identifiable, Equatable, Sendable {
    var id: String { folder.lastPathComponent }
    let folder: URL
    let date: Date
    let reason: String

    var reasonTitle: String {
        switch reason {
        case "auto": return "Automatisch (täglich)"
        case "update": return "Vor App-Update"
        case "restore": return "Vor Wiederherstellung"
        case "manual": return "Manuell"
        case "replaced": return "Beiseitegelegt"
        default: return reason
        }
    }
}

struct JSONBackupInfo: Identifiable, Equatable, Sendable {
    var id: String { url.lastPathComponent }
    let url: URL
    let date: Date
    let reason: String
}

struct StoreSafety: Sendable {

    let root: URL

    init(root: URL = StoreSafety.defaultRoot) {
        self.root = root
    }

    static var defaultRoot: URL {
        URL.applicationSupportDirectory.appending(path: "ZARA-Backups", directoryHint: .isDirectory)
    }

    private var storeRoot: URL { root.appending(path: "store", directoryHint: .isDirectory) }
    private var jsonRoot: URL { root.appending(path: "json", directoryHint: .isDirectory) }

    // MARK: Zeitstempel im Ordnernamen

    private static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }

    private static func parseStamp(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.date(from: text)
    }

    /// Die Dateien eines SwiftData-Stores: Haupt-, WAL- und SHM-Datei.
    private func storeFiles(for storeURL: URL) -> [URL] {
        let base = storeURL.path
        return [storeURL, URL(fileURLWithPath: base + "-wal"), URL(fileURLWithPath: base + "-shm")]
    }

    // MARK: Schnappschuesse der Datenbank

    /// Kopiert den Store vor dem Oeffnen. Gibt `nil` zurueck, wenn es (noch) keinen Store gibt.
    @discardableResult
    func snapshotStore(at storeURL: URL, reason: String, now: Date = .now) throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return nil }
        let folder = storeRoot.appending(path: "\(Self.stamp(now))-\(reason)", directoryHint: .isDirectory)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in storeFiles(for: storeURL) where fm.fileExists(atPath: file.path) {
            let target = folder.appending(path: file.lastPathComponent)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: file, to: target)
        }
        prune()
        return folder
    }

    func listSnapshots() -> [StoreSnapshotInfo] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: storeRoot, includingPropertiesForKeys: nil) else { return [] }
        return entries.compactMap { url -> StoreSnapshotInfo? in
            let name = url.lastPathComponent
            guard name.count > 16, let date = Self.parseStamp(String(name.prefix(15))) else { return nil }
            let reason = String(name.dropFirst(16))
            return StoreSnapshotInfo(folder: url, date: date, reason: reason)
        }
        .sorted { $0.date > $1.date }
    }

    /// Stellt einen Schnappschuss wieder her. Der aktuelle Store wird vorher beiseitegelegt (nicht geloescht).
    func restore(_ snapshot: StoreSnapshotInfo, to storeURL: URL, now: Date = .now) throws {
        let fm = FileManager.default
        try moveAside(storeURL: storeURL, now: now)
        for file in storeFiles(for: storeURL) {
            let source = snapshot.folder.appending(path: file.lastPathComponent)
            if fm.fileExists(atPath: source.path) { try fm.copyItem(at: source, to: file) }
        }
    }

    /// Legt die aktuellen Store-Dateien in den Sicherungsordner („replaced") – ohne Datenverlust.
    func moveAside(storeURL: URL, now: Date = .now) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }
        let folder = storeRoot.appending(path: "\(Self.stamp(now))-replaced", directoryHint: .isDirectory)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in storeFiles(for: storeURL) where fm.fileExists(atPath: file.path) {
            try fm.moveItem(at: file, to: folder.appending(path: file.lastPathComponent))
        }
    }

    /// Letzte automatische Sicherung aelter als `hours` (oder keine vorhanden)?
    func isAutoSnapshotDue(hours: Double = 20, now: Date = .now) -> Bool {
        guard let last = listSnapshots().first(where: { $0.reason == "auto" || $0.reason == "update" }) else { return true }
        return now.timeIntervalSince(last.date) > hours * 3600
    }

    // MARK: JSON-Backups

    @discardableResult
    func writeJSONBackup(_ data: Data, reason: String, now: Date = .now) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: jsonRoot, withIntermediateDirectories: true)
        let url = jsonRoot.appending(path: "zara-\(Self.stamp(now))-\(reason).json")
        try data.write(to: url, options: .atomic)
        prune()
        return url
    }

    func listJSONBackups() -> [JSONBackupInfo] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: jsonRoot, includingPropertiesForKeys: nil) else { return [] }
        return entries.compactMap { url -> JSONBackupInfo? in
            let name = url.deletingPathExtension().lastPathComponent   // zara-yyyyMMdd-HHmmss-reason
            guard name.hasPrefix("zara-"), name.count > 21,
                  let date = Self.parseStamp(String(name.dropFirst(5).prefix(15))) else { return nil }
            return JSONBackupInfo(url: url, date: date, reason: String(name.dropFirst(21)))
        }
        .sorted { $0.date > $1.date }
    }

    func isAutoJSONDue(hours: Double = 20, now: Date = .now) -> Bool {
        guard let last = listJSONBackups().first else { return true }
        return now.timeIntervalSince(last.date) > hours * 3600
    }

    // MARK: Aufraeumen

    /// Behaelt je Art die neuesten: automatisch 7, alles andere 5. „replaced" bleibt immer erhalten.
    func prune() {
        let fm = FileManager.default
        let snaps = listSnapshots().filter { $0.reason != "replaced" }
        for group in [snaps.filter { $0.reason == "auto" }, snaps.filter { $0.reason != "auto" }] {
            let limit = (group.first?.reason == "auto") ? 7 : 5
            for old in group.dropFirst(limit) { try? fm.removeItem(at: old.folder) }
        }
        let jsons = listJSONBackups()
        for group in [jsons.filter { $0.reason == "auto" }, jsons.filter { $0.reason != "auto" }] {
            let limit = (group.first?.reason == "auto") ? 7 : 5
            for old in group.dropFirst(limit) { try? fm.removeItem(at: old.url) }
        }
    }
}
