//
//  Layout.swift
//  DariApp
//
//  Layout-Tokens: Abstaende, Radien, Schatten. Ein einziger Ort fuer
//  raeumliche Konstanten sorgt fuer visuelle Konsistenz in der ganzen App.
//

import SwiftUI

/// Abstufungen fuer Abstaende (4-pt-Raster).
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Eckenradien fuer abgerundete Karten und Felder.
enum CornerRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let pill: CGFloat = 999
}

/// Wiederverwendbare Schattenstile (sehr dezent gehalten).
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let soft = ShadowStyle(color: Palette.shadow, radius: 12, x: 0, y: 4)
    static let subtle = ShadowStyle(color: Palette.shadow, radius: 6, x: 0, y: 2)
}

extension View {
    /// Wendet einen definierten Schattenstil an.
    func dariShadow(_ style: ShadowStyle = .soft) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
