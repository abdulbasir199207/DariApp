//
//  AnswerChecker.swift
//  DariApp
//
//  Prueft eine Nutzereingabe gegen die gueltigen Loesungen einer Karte.
//
//  Regeln (laut Spezifikation):
//  - Gross-/Kleinschreibung ignorieren.
//  - Ueberfluessige Leerzeichen ignorieren.
//  - Rechtschreibung muss korrekt sein.
//  - Unterscheidung: perfekt richtig / kleiner Tippfehler / komplett falsch.
//
//  Fuer persische Eingaben werden zusaetzlich haeufige Schreibvarianten
//  (arabische vs. persische Zeichen, diakritische Zeichen) normalisiert,
//  damit die Bewertung fair bleibt.
//

import Foundation

enum AnswerChecker {

    /// Bewertet `input` gegen die Menge gueltiger `solutions`.
    /// - Parameter isPersian: Aktiviert persische Zeichennormalisierung.
    static func evaluate(
        input: String,
        against solutions: [String],
        isPersian: Bool
    ) -> AnswerQuality {

        let normalizedInput = normalize(input, isPersian: isPersian)
        guard !normalizedInput.isEmpty else { return .wrong }

        let normalizedSolutions = solutions
            .map { normalize($0, isPersian: isPersian) }
            .filter { !$0.isEmpty }

        // 1) Exakter Treffer gegen irgendeine gueltige Loesung?
        if normalizedSolutions.contains(normalizedInput) {
            return .perfect
        }

        // 2) Kleiner Tippfehler? Levenshtein-Distanz von 1 gegen die
        //    naechstliegende Loesung, sofern die Loesung lang genug ist.
        for solution in normalizedSolutions {
            let distance = levenshtein(normalizedInput, solution)
            // Bei sehr kurzen Woertern ist 1 Fehler bereits "komplett falsch".
            let tolerance = solution.count >= 4 ? 1 : 0
            if distance <= tolerance && distance > 0 {
                return .typo
            }
        }

        return .wrong
    }

    // MARK: - Normalisierung

    static func normalize(_ text: String, isPersian: Bool) -> String {
        var result = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Mehrfache Leerzeichen auf eines reduzieren.
        result = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if isPersian {
            result = normalizePersian(result)
        }
        return result
    }

    /// Vereinheitlicht haeufige persische/arabische Zeichenvarianten und
    /// entfernt diakritische Zeichen (Tashkil), die nicht abgefragt werden.
    private static func normalizePersian(_ text: String) -> String {
        var s = text
        let replacements: [Character: Character] = [
            "ي": "ی", // arabisches Ya -> persisches Ya
            "ك": "ک", // arabisches Kaf -> persisches Kaf
            "ۀ": "ه",
            "ة": "ه",
            "أ": "ا",
            "إ": "ا",
            "آ": "ا",
            "ؤ": "و"
        ]
        s = String(s.map { replacements[$0] ?? $0 })

        // Diakritika / Tashkil und Zero-Width-Joiner entfernen.
        let strip: Set<Character> = [
            "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}",
            "\u{0650}", "\u{0651}", "\u{0652}", "\u{0670}",
            "\u{200C}", "\u{200D}", "\u{FEFF}"
        ]
        s = String(s.filter { !strip.contains($0) })
        return s
    }

    // MARK: - Levenshtein

    /// Klassische Levenshtein-Editierdistanz (Zeichenebene).
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,       // Loeschen
                    current[j - 1] + 1,    // Einfuegen
                    previous[j - 1] + cost // Ersetzen
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
