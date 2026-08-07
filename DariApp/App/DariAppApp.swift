//
//  DariAppApp.swift
//  DariApp
//
//  App-Einstiegspunkt. Erzeugt den SwiftData-Container und die globalen
//  Einstellungen und injiziert beide in die View-Hierarchie.
//

import SwiftUI
import SwiftData

@main
struct DariAppApp: App {

    /// Persistenter SwiftData-Container (eine Instanz fuer die App-Laufzeit).
    private let modelContainer = ModelContainerFactory.makeShared()

    /// Globale Einstellungen (beobachtbar).
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(\.animationsEnabled, settings.animationsEnabled)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Palette.sage)
        }
        .modelContainer(modelContainer)
    }
}
