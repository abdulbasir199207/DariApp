//
//  Palette.swift
//  DariApp
//
//  Farbwelt der App: natuerliche Pastelltoene, inspiriert von orientalischer
//  Architektur (Medersa Ben Youssef) – ruhig, elegant, nicht kitschig.
//  Alle Farben sind dynamisch (Light/Dark) definiert und werden semantisch
//  benannt, damit Views nie mit Rohwerten arbeiten.
//

import SwiftUI

extension Color {
    /// Erzeugt eine an das Farbschema angepasste (dynamische) Farbe.
    init(light: Color, dark: Color) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Bequemer Hex-Initializer (RGB, ohne Alpha).
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Zentrale, semantische Farbpalette.
enum Palette {

    // MARK: Hintergruende
    /// App-Hintergrund (grosse Cremeflaeche / tiefes Anthrazit im Dark Mode).
    static let background = Color(light: Color(hex: 0xF7F3EC), dark: Color(hex: 0x14130F))
    /// Kartenoberflaeche.
    static let surface = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1F1D18))
    /// Leicht abgesetzte Sekundaerflaeche (Felder, Chips).
    static let surfaceSecondary = Color(light: Color(hex: 0xEFE9DE), dark: Color(hex: 0x2A2822))

    // MARK: Text
    static let textPrimary = Color(light: Color(hex: 0x2C2A24), dark: Color(hex: 0xF2EEE5))
    static let textSecondary = Color(light: Color(hex: 0x726C5E), dark: Color(hex: 0xA8A192))

    // MARK: Akzente
    /// Salbeigruen – ruhiger Primaerakzent.
    static let sage = Color(light: Color(hex: 0x8FA98C), dark: Color(hex: 0x9DB89A))
    /// Helles Tuerkis – sekundaerer Akzent.
    static let turquoise = Color(light: Color(hex: 0x7FC5C0), dark: Color(hex: 0x86CFC9))
    /// Terrakotta – warmer Signalakzent (sparsam einsetzen).
    static let terracotta = Color(light: Color(hex: 0xC77B58), dark: Color(hex: 0xD68A66))
    /// Sand – neutraler Zusatzton.
    static let sand = Color(light: Color(hex: 0xDCCEB5), dark: Color(hex: 0x3A3529))

    // MARK: Semantisch (Feedback)
    static let success = sage
    static let warning = Color(light: Color(hex: 0xD9A441), dark: Color(hex: 0xE0B25C))
    static let error = terracotta

    // MARK: Trennlinien / Schatten
    static let separator = Color(light: Color(hex: 0xE3DCCF), dark: Color(hex: 0x33302A))
    static let shadow = Color(light: Color.black.opacity(0.06), dark: Color.black.opacity(0.35))
}
