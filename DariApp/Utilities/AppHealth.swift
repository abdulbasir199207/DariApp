//
//  AppHealth.swift
//  DariApp
//
//  Zentrale Stelle fuer Speicherfehler: Statt Fehler mit `try?` zu verschlucken,
//  merkt sich die App den letzten Fehler und zeigt dem Nutzer einen Hinweis
//  (inkl. Aufforderung, ein Backup zu sichern).
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class AppHealth {

    static let shared = AppHealth()

    /// Verstaendliche Beschreibung des letzten Speicherfehlers (nil = alles gut).
    var lastSaveError: String?

    /// Wurde die App im Wiederherstellungsmodus gestartet? (Container nicht oeffenbar)
    var startupIssue: String?

    func reportSaveFailure(_ error: Error) {
        lastSaveError = "Speichern fehlgeschlagen. Bitte sichere jetzt ein Backup. (\(error.localizedDescription))"
    }

    func clearSaveError() { lastSaveError = nil }
}

extension ModelContext {

    /// Speichert und meldet Fehler an `AppHealth`, statt sie zu verschlucken.
    /// - Returns: `true`, wenn erfolgreich gespeichert wurde.
    @MainActor
    @discardableResult
    func saveReporting() -> Bool {
        do {
            if hasChanges { try save() }
            AppHealth.shared.clearSaveError()
            return true
        } catch {
            AppHealth.shared.reportSaveFailure(error)
            return false
        }
    }
}
