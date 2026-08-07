//
//  CardSurface.swift
//  DariApp
//
//  Wiederverwendbarer, abgerundeter Karten-Container mit dezentem Schatten.
//  Grundbaustein fast aller Flaechen in der App.
//

import SwiftUI

struct CardSurface<Content: View>: View {
    var padding: CGFloat = Spacing.md
    var cornerRadius: CGFloat = CornerRadius.md
    var shadow: ShadowStyle = .soft
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .dariShadow(shadow)
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        CardSurface {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Haus").font(DariFont.headline).foregroundStyle(Palette.textPrimary)
                Text("khâne").font(DariFont.caption).foregroundStyle(Palette.textSecondary)
            }
        }
        .padding()
    }
}
