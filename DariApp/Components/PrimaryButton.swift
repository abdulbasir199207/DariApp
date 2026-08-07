//
//  PrimaryButton.swift
//  DariApp
//
//  Zentrale Buttons der App. Ein `ButtonStyle` statt vieler Einzelmodifier,
//  damit alle Buttons konsistent aussehen und sich gleich anfuehlen.
//

import SwiftUI

/// Gefuellter Primaerbutton (Salbeigruen).
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.sage
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DariFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm + 2)
            .background(tint.opacity(isEnabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Sekundaerbutton (getoent, ohne Fuellung).
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.sage

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DariFont.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm + 2)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var dariPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func dariPrimary(tint: Color) -> PrimaryButtonStyle { PrimaryButtonStyle(tint: tint) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var dariSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func dariSecondary(tint: Color) -> SecondaryButtonStyle { SecondaryButtonStyle(tint: tint) }
}
