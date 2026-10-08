//
//  AnswerChecker.swift
//  DariApp
//
//  Prueft eine Nutzereingabe gegen die gueltigen Loesungen.
//
//  Regeln (identisch zur Web-Version):
//  - Gross-/Kleinschreibung, ueberfluessige Leerzeichen und Satzzeichen am
//    Rand zaehlen nicht. Ziffern ۱۲۳ und ١٢٣ gelten wie 123.
//  - Persisch: Zeichenvarianten (arabisches Ya/Kaf), Diakritika, Tatweel und
//    Halbleerzeichen (ZWNJ) werden vereinheitlicht. „آ" (Alef mit Madda) bleibt
//    unterscheidbar: „اب" statt „آب" ist nur ein Tippfehler.
//  - Deutsch: ä/ö/ü/ß duerfen als ae/oe/ue/ss getippt werden; ein fehlender
//    Artikel zaehlt als Tippfehler.
//  - WICHTIG: Persische Zeichen werden auf Ebene der Unicode-Skalare bearbeitet.
//    Diakritika und das ZWNJ haengen als „Extend"-Zeichen an ihrem Vorgaenger
//    und waeren als `Character` nicht einzeln entfernbar.
//

import Foundation

enum AnswerChecker {

    // MARK: - Oeffentliche API

    /// Bewertet `input` gegen die Menge gueltiger `solutions`.
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
        if normalizedSolutions.contains(normalizedInput) { return .perfect }

        // 2) Variante oder kleiner Tippfehler?
        let foldedInput = fold(normalizedInput, isPersian: isPersian)
        var best: AnswerQuality = .wrong
        for solution in normalizedSolutions {
            let foldedSolution = fold(solution, isPersian: isPersian)
            if foldedInput == foldedSolution {
                if !isPersian { return .perfect }   // ae/oe/ue/ss-Schreibweise ist korrekt
                best = .typo                        // آ/ا-Verwechslung
                continue
            }
            if !isPersian, stripArticle(solution) == normalizedInput, solution != normalizedInput {
                best = .typo
                continue
            }
            let distance = levenshtein(foldedInput, foldedSolution)
            // Bei sehr kurzen Woertern ist 1 Fehler bereits "komplett falsch".
            let tolerance = foldedSolution.unicodeScalars.count >= 4 ? 1 : 0
            if distance > 0 && distance <= tolerance { best = .typo }
        }
        return best
    }

    /// Satzbewertung: die Toleranz waechst mit der Laenge (max. ~8 %).
    static func evaluateSentence(
        input: String,
        against solutions: [String],
        isPersian: Bool
    ) -> AnswerQuality {
        let normalizedInput = fold(normalize(input, isPersian: isPersian), isPersian: isPersian)
        guard !normalizedInput.isEmpty else { return .wrong }
        var best: AnswerQuality = .wrong
        for solution in solutions {
            let normalizedSolution = fold(normalize(solution, isPersian: isPersian), isPersian: isPersian)
            if normalizedInput == normalizedSolution { return .perfect }
            let tolerance = max(1, Int(Double(normalizedSolution.unicodeScalars.count) * 0.08))
            if levenshtein(normalizedInput, normalizedSolution) <= tolerance { best = .typo }
        }
        return best
    }

    // MARK: - Normalisierung

    private static let edgeCharacters: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: ".,;:!?'\"“”„‚‘’«»()[]-–—…،؛؟")
        return set
    }()

    private static let persianMap: [Unicode.Scalar: Unicode.Scalar] = [
        "\u{064A}": "\u{06CC}", // ي -> ی
        "\u{0643}": "\u{06A9}", // ك -> ک
        "\u{06C0}": "\u{0647}", // ۀ -> ه
        "\u{0629}": "\u{0647}", // ة -> ه
        "\u{0623}": "\u{0627}", // أ -> ا
        "\u{0625}": "\u{0627}", // إ -> ا
        "\u{0624}": "\u{0648}", // ؤ -> و
        "\u{0649}": "\u{06CC}"  // ى -> ی
    ]

    private static let persianStrip: Set<Unicode.Scalar> = [
        "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}",
        "\u{0650}", "\u{0651}", "\u{0652}", "\u{0670}", "\u{0640}",
        "\u{200C}", "\u{200D}", "\u{FEFF}"
    ]

    private static let articles: Set<String> = [
        "der", "die", "das", "ein", "eine", "einen", "einem", "einer", "den", "dem", "des"
    ]

    static func normalize(_ text: String, isPersian: Bool) -> String {
        var result = text
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        result = mapDigits(result)
        result = result.trimmingCharacters(in: edgeCharacters)

        // Mehrfache Leerzeichen auf eines reduzieren.
        result = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if isPersian { result = normalizePersian(result) }
        return result
    }

    /// Arabisch-indische (٠–٩) und persische (۰–۹) Ziffern -> 0–9.
    private static func mapDigits(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0660...0x0669: scalars.append(Unicode.Scalar(0x30 + scalar.value - 0x0660)!)
            case 0x06F0...0x06F9: scalars.append(Unicode.Scalar(0x30 + scalar.value - 0x06F0)!)
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// Vereinheitlicht persische/arabische Zeichenvarianten und entfernt Diakritika.
    private static func normalizePersian(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if persianStrip.contains(scalar) { continue }
            scalars.append(persianMap[scalar] ?? scalar)
        }
        return String(scalars)
    }

    /// Groebere Faltung nur fuer den Vergleich „zaehlt als Variante".
    private static func fold(_ text: String, isPersian: Bool) -> String {
        if isPersian {
            return text.replacingOccurrences(of: "\u{0622}", with: "\u{0627}") // آ -> ا
        }
        return text
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
    }

    private static func stripArticle(_ text: String) -> String {
        guard let space = text.firstIndex(of: " ") else { return text }
        let first = String(text[text.startIndex..<space])
        return articles.contains(first) ? String(text[text.index(after: space)...]) : text
    }

    // MARK: - Levenshtein

    /// Klassische Levenshtein-Editierdistanz (auf Unicode-Skalaren, wie in der Web-Version).
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a.unicodeScalars)
        let b = Array(b.unicodeScalars)
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
