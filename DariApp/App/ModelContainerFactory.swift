//
//  ModelContainerFactory.swift
//  DariApp
//
//  Zentrale Erzeugung des SwiftData-ModelContainers. Kapselt das Schema
//  an einer Stelle und bietet zusaetzlich einen In-Memory-Container fuer
//  Previews und Tests (Dependency Injection / Testbarkeit).
//

import Foundation
import SwiftData

enum ModelContainerFactory {

    /// Alle persistierten Modelltypen.
    static let schema = Schema([
        Card.self,
        Tag.self,
        ReviewLog.self
    ])

    /// Produktiver, auf der Festplatte gespeicherter Container (offline, lokal).
    static func makeShared() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
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
