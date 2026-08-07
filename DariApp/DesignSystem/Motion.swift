//
//  Motion.swift
//  DariApp
//
//  Zentrale Animationskurven und ein Environment-Wert, mit dem die gesamte
//  App Animationen abschalten kann (Einstellung "Animationen aus").
//  So muss keine View die Einstellung selbst kennen.
//

import SwiftUI

enum Motion {
    /// Standard-Feder fuer Uebergaenge (Navigation, Einblenden).
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.82)
    /// Etwas lebendigere Feder fuer den Kartenflip.
    static let flip = Animation.spring(response: 0.5, dampingFraction: 0.8)
    /// Sanftes Ein-/Ausblenden.
    static let fade = Animation.easeInOut(duration: 0.25)
}

// MARK: - Environment: Animationen aktiv?

private struct AnimationsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Ob dekorative Animationen ausgefuehrt werden sollen.
    var animationsEnabled: Bool {
        get { self[AnimationsEnabledKey.self] }
        set { self[AnimationsEnabledKey.self] = newValue }
    }
}

extension View {
    /// Wendet eine Animation nur an, wenn Animationen aktiviert sind.
    /// Zieht den Schalter aus dem Environment.
    func dariAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ConditionalAnimation(animation: animation, value: value))
    }
}

private struct ConditionalAnimation<V: Equatable>: ViewModifier {
    @Environment(\.animationsEnabled) private var enabled
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(enabled ? animation : nil, value: value)
    }
}
