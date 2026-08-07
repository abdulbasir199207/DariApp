//
//  Typography.swift
//  DariApp
//
//  Typografie-Skala auf Basis der dynamischen System-Schrift (Dynamic Type).
//  Fuer persische Schrift wird eine groessere Zeile gewaehlt, da die Glyphen
//  hoehere Detailtiefe haben und mehr Luft brauchen.
//

import SwiftUI

enum DariFont {
    /// Grosse Titel (Screen-Headlines).
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    /// Abschnittstitel.
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    /// Betonter Fliesstext.
    static let headline = Font.system(.headline, design: .rounded)
    /// Standard-Fliesstext.
    static let body = Font.system(.body, design: .rounded)
    /// Sekundaerer, kleiner Text.
    static let caption = Font.system(.caption, design: .rounded)

    /// Grosse Darstellung eines deutschen Lernbegriffs auf der Karte.
    static let learnTermGerman = Font.system(size: 34, weight: .semibold, design: .rounded)
    /// Grosse Darstellung eines persischen Begriffs (etwas groesser, klare Serif-lose Form).
    static let learnTermPersian = Font.system(size: 42, weight: .medium, design: .default)
    /// Lautschrift – dezent, kursiv.
    static let transliteration = Font.system(.title3, design: .serif).italic()
}

extension Text {
    /// Kennzeichnet persischen Text: rechtsbuendig, RTL-Ausrichtung.
    func persianStyle() -> some View {
        self
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
    }
}
