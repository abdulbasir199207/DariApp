//
//  ModelContainerFactory.swift
//  DariApp
//
//  Zentrale Erzeugung des SwiftData-ModelContainers. Kapselt das Schema
//  an einer Stelle und bietet zusaetzlich einen In-Memory-Container fuer
//  Previews und Tests (Dependency Injection / Testbarkeit).
//
//  Datensicherheit: Vor dem Oeffnen des Stores wird bei Bedarf eine Kopie
//  angelegt (nach App-Updates und taeglich). Schlaegt das Oeffnen fehl, stuerzt
//  die App NICHT ab: Sie startet im Wiederherstellungsmodus (RecoveryView),
//  die Datenbank-Dateien bleiben unveraendert erhalten.
//

import Foundation
import SwiftData

enum ModelContainerFactory {

    /// Alle persistierten Modelltypen.
    static let schema = Schema([
        Card.self,
        Tag.self,
        ReviewLog.self,
        ItemStat.self
    ])

    /// Ergebnis des Starts: ein Container und ggf. eine Beschreibung des Problems.
    struct Outcome {
        let container: ModelContainer
        let storeURL: URL
        /// nil = alles in Ordnung. Sonst laeuft die App mit einem fluechtigen Container.
        let issue: String?
    }

    private static let lastVersionKey = "zara.lastLaunchVersion"

    /// Produktiver, auf der Festplatte gespeicherter Container (offline, lokal).
    @MainActor
    static func makeShared(safety: StoreSafety = StoreSafety(), defaults: UserDefaults = .standard) -> Outcome {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let storeURL = configuration.url

        // UI-Tests starten mit einer fluechtigen Datenbank (saubere Ausgangslage, nie echte Daten).
        if ProcessInfo.processInfo.arguments.contains("-zaraInMemory") {
            return Outcome(container: makeInMemory(), storeURL: storeURL, issue: nil)
        }

        // 1) Sicherungskopie VOR dem Oeffnen (nach Update und taeglich).
        let version = BackupService.appVersionString
        if FileManager.default.fileExists(atPath: storeURL.path) {
            if defaults.string(forKey: lastVersionKey) != version {
                _ = try? safety.snapshotStore(at: storeURL, reason: "update")
            } else if safety.isAutoSnapshotDue() {
                _ = try? safety.snapshotStore(at: storeURL, reason: "auto")
            }
        }

        // 2) Oeffnen – ohne fatalError.
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            defaults.set(version, forKey: lastVersionKey)
            return Outcome(container: container, storeURL: storeURL, issue: nil)
        } catch {
            let message = "Die Datenbank konnte nicht geöffnet werden: \(error.localizedDescription)"
            return Outcome(container: makeInMemory(), storeURL: storeURL, issue: message)
        }
    }

    /// Fluechtiger Container fuer Previews/Tests.
    static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("In-Memory-Container konnte nicht erstellt werden: \(error)")
        }
    }
}
