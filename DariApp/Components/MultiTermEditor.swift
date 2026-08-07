//
//  MultiTermEditor.swift
//  DariApp
//
//  Editiert eine dynamische Liste von Begriffen (mehrere Uebersetzungen
//  je Seite). Leere Felder werden beim Speichern ignoriert.
//
//  Zur Tastatur: iOS erlaubt kein hartes Erzwingen einer Sprach-Tastatur.
//  Ueber `textContentType`/`keyboardType` und Deaktivieren der
//  Autokorrektur bei persischem Text geben wir iOS die bestmoeglichen
//  Hinweise, damit moeglichst die passende Tastatur erscheint.
//

import SwiftUI

struct MultiTermEditor: View {
    @Binding var terms: [String]
    let placeholder: String
    let isPersian: Bool

    var body: some View {
        ForEach(terms.indices, id: \.self) { index in
            HStack {
                TextField(placeholder, text: binding(for: index))
                    .modifier(TermFieldStyle(isPersian: isPersian))
                if terms.count > 1 {
                    Button(role: .destructive) {
                        terms.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        Button {
            terms.append("")
        } label: {
            Label("Begriff hinzufuegen", systemImage: "plus")
                .font(DariFont.caption)
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < terms.count ? terms[index] : "" },
            set: { if index < terms.count { terms[index] = $0 } }
        )
    }
}

/// Feld-Styling inkl. Tastatur-Hinweisen fuer die jeweilige Sprache.
private struct TermFieldStyle: ViewModifier {
    let isPersian: Bool

    func body(content: Content) -> some View {
        if isPersian {
            content
                .environment(\.layoutDirection, .rightToLeft)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(size: 20))
        } else {
            content
                .textInputAutocapitalization(.sentences)
        }
    }
}
