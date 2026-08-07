//
//  TagChip.swift
//  DariApp
//
//  Kompakte, abgerundete Darstellung eines Tags. Optional auswaehlbar
//  (fuer Filter) und optional mit Entfernen-Aktion (fuer den Editor).
//

import SwiftUI

struct TagChip: View {
    let title: String
    var isSelected: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Text(title)
                .font(DariFont.caption)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(isSelected ? .white : Palette.textPrimary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs + 2)
        .background(isSelected ? Palette.sage : Palette.surfaceSecondary)
        .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        TagChip(title: "Familie")
        TagChip(title: "Verben", isSelected: true)
        TagChip(title: "Reise", onRemove: {})
    }
    .padding()
    .background(Palette.background)
}
