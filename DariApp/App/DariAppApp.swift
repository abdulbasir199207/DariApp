//
//  DariAppApp.swift
//  DariApp
//
//  App-Einstiegspunkt (Anzeigename „ZARA"). Erzeugt den SwiftData-Container und
//  die globalen Einstellungen und injiziert beide in die View-Hierarchie.
//  Der interne Projekt-/Modulname bleibt „DariApp", damit Bundle-ID und damit
//  die Daten auf dem Geraet bei Updates erhalten bleiben.
//

import SwiftUI
import SwiftData

@main
struct DariAppApp: App {

    /// Container + Startergebnis (eine Instanz fuer die App-Laufzeit).
    private let outcome = ModelContainerFactory.makeShared()

    /// Globale Einstellungen (beobachtbar).
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            Group {
                if let issue = outcome.issue {
                    RecoveryView(issue: issue, storeURL: outcome.storeURL)
                } else {
                    RootView()
                }
            }
            .environment(settings)
            .environment(AppHealth.shared)
            .environment(\.animationsEnabled, settings.animationsEnabled)
            .preferredColorScheme(settings.appearance.colorScheme)
            .tint(Palette.sage)
        }
        .modelContainer(outcome.container)
    }
}
