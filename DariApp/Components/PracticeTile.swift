//
//  PracticeTile.swift
//  DariApp
//
//  Kachel fuer Startseite und Uebungs-Uebersicht (Icon, Titel, Untertitel, Badge).
//

import SwiftUI
import UIKit

struct PracticeTileLabel: View {
    let icon: String
    let title: String
    let subtitle: String
    var badge: Int = 0
    var isEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Palette.sage)
            Text(title)
                .font(DariFont.headline)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(subtitle)
                .font(DariFont.caption)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(Spacing.md)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
        .dariShadow(.subtle)
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                Text("\(badge)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Palette.terracotta)
                    .clipShape(Capsule())
                    .padding(Spacing.sm)
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Teilen-Dialog (z. B. „In Dateien sichern") fuer eine Datei.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onComplete: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
