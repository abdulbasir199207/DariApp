//
//  SyncService.swift
//  DariApp
//
//  Abgleich mit dem eigenen Server (NUC, „ZARA-Sync").
//  - Nach jeder Änderung wird der aktuelle Stand (Format „zara-backup", ohne Audio)
//    an den Server geschickt. Der Server bewahrt JEDEN Stand auf und löscht nie.
//  - Beim Start und beim Zurückkehren in die App wird der neueste Server-Stand geholt
//    und ZUSAMMENGEFÜHRT (RestoreMode.merge – es geht nichts verloren). Vorher wird
//    lokal eine JSON-Sicherung angelegt („vor-sync").
//  - Aus, solange kein Server und Schlüssel eingetragen sind. Offline bleibt alles wie bisher.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SyncService {

    static let shared = SyncService()

    private enum Keys {
        static let url = "zara.sync.url"
        static let key = "zara.sync.key"
        static let enabled = "zara.sync.enabled"
        static let lastPushAt = "zara.sync.lastPushAt"
        static let lastPullAt = "zara.sync.lastPullAt"
        static let lastOkAt = "zara.sync.lastOkAt"
    }

    private let defaults: UserDefaults
    private var pending: Task<Void, Never>?
    @ObservationIgnored private var pendingContext: ModelContext?
    @ObservationIgnored private var pendingSettings: AppSettings?
    private(set) var busy = false
    private(set) var applying = false
    private(set) var lastError: String?

    var serverURL: String { didSet { defaults.set(serverURL, forKey: Keys.url) } }
    var accessKey: String { didSet { defaults.set(accessKey, forKey: Keys.key) } }
    var enabled: Bool { didSet { defaults.set(enabled, forKey: Keys.enabled) } }
    private(set) var lastOkAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverURL = defaults.string(forKey: Keys.url) ?? "http://10.0.0.201:8090"
        accessKey = defaults.string(forKey: Keys.key) ?? ""
        enabled = defaults.bool(forKey: Keys.enabled)
        let ok = defaults.double(forKey: Keys.lastOkAt)
        lastOkAt = ok > 0 ? Date(timeIntervalSince1970: ok / 1000) : nil
    }

    var isReady: Bool { enabled && !accessKey.isEmpty && baseURL != nil }

    private var baseURL: URL? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed)
    }

    private func request(_ method: String, _ path: String, body: Data? = nil) -> URLRequest? {
        guard let base = baseURL, let url = URL(string: base.absoluteString + path) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = method
        req.setValue("Bearer " + accessKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        return req
    }

    private func markOK() {
        let ms = (Date.now.timeIntervalSince1970 * 1000).rounded()
        defaults.set(ms, forKey: Keys.lastOkAt)
        lastOkAt = .now
        lastError = nil
    }

    // MARK: - Senden

    @discardableResult
    func push(context: ModelContext, settings: AppSettings) async -> Bool {
        guard isReady, !applying else { return false }
        do {
            let data = try BackupService(context: context, settings: settings).makeBackup(includeAudio: false)
            guard let req = request("PUT", "/api/backup", body: data) else { throw BackupError.invalid("Server-Adresse ungültig") }
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw BackupError.invalid("Server antwortet \(code)") }
            if case .success(let parsed) = BackupService.parse(data), let created = parsed.createdAt {
                defaults.set((created.timeIntervalSince1970 * 1000).rounded(), forKey: Keys.lastPushAt)
            }
            markOK()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Nach einer Änderung: Senden verzögert einplanen (mehrere Änderungen = ein Upload).
    func schedulePush(context: ModelContext, settings: AppSettings) {
        guard isReady, !applying else { return }
        pendingContext = context
        pendingSettings = settings
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, let ctx = self.pendingContext, let st = self.pendingSettings else { return }
            await self.push(context: ctx, settings: st)
        }
    }

    /// App geht in den Hintergrund: geplanten Upload sofort ausführen.
    func flush() async {
        guard pending != nil, let ctx = pendingContext, let st = pendingSettings else { return }
        pending?.cancel()
        pending = nil
        await push(context: ctx, settings: st)
    }

    // MARK: - Holen und zusammenführen

    /// Holt den neuesten Server-Stand und führt ihn zusammen, wenn er von einem anderen Gerät stammt.
    /// Gibt `true` zurück, wenn lokale Daten ergänzt wurden.
    @discardableResult
    func pull(context: ModelContext, settings: AppSettings) async -> Bool {
        guard isReady, !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            guard let req = request("GET", "/api/backup/latest") else { throw BackupError.invalid("Server-Adresse ungültig") }
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 404 {                        // Server noch leer: ersten Stand hochladen
                await push(context: context, settings: settings)
                return false
            }
            guard (200..<300).contains(code) else { throw BackupError.invalid("Server antwortet \(code)") }
            let parsed: ParsedBackup
            switch BackupService.parse(data) {
            case .success(let p): parsed = p
            case .failure(let e): throw e
            }
            let seen = max(defaults.double(forKey: Keys.lastPushAt), defaults.double(forKey: Keys.lastPullAt))
            let remote = parsed.createdAt.map { ($0.timeIntervalSince1970 * 1000).rounded() } ?? .infinity
            guard remote > seen else { markOK(); return false }

            let service = BackupService(context: context, settings: settings)
            // Lokale Sicherung vor dem Zusammenführen (zusätzlich zu den täglichen Sicherungen).
            if let before = try? service.makeBackup(includeAudio: false) {
                _ = try? StoreSafety().writeJSONBackup(before, reason: "vor-sync")
            }
            applying = true
            do { try service.apply(parsed, mode: .merge) } catch { applying = false; throw error }
            defaults.set(remote.isFinite ? remote : (Date.now.timeIntervalSince1970 * 1000).rounded(), forKey: Keys.lastPullAt)
            applying = false
            await push(context: context, settings: settings)   // zusammengeführten Stand zurückschicken
            markOK()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
