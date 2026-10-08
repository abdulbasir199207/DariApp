//
//  SampleCards.swift
//  DariApp
//
//  Beispielkarten zum Ausprobieren (gleiche wie in der Web-Version).
//

import Foundation
import SwiftData

enum SampleCards {

    /// Legt die Beispielkarten an (ohne vorhandene Tags doppelt zu erzeugen).
    @MainActor
    static func insert(into context: ModelContext) {
        var tags: [String: Tag] = [:]
        for tag in (try? context.fetch(FetchDescriptor<Tag>())) ?? [] { tags[tag.name] = tag }
        func tag(_ name: String) -> Tag {
            if let existing = tags[name] { return existing }
            let created = Tag(name: name)
            context.insert(created)
            tags[name] = created
            return created
        }
        let samples: [(de: [String], fa: [String], tr: String, tags: [String])] = [
            (["Haus", "Gebäude"], ["خانه", "منزل"], "khâne", ["Alltag"]),
            (["Mutter"], ["مادر"], "mâdar", ["Familie"]),
            (["Vater"], ["پدر"], "pedar", ["Familie"]),
            (["Wasser"], ["آب"], "âb", ["Alltag"]),
            (["gehen"], ["رفتن"], "raftan", ["Verben"]),
            (["essen"], ["خوردن"], "khordan", ["Verben"]),
            (["Brot"], ["نان"], "nân", ["Alltag"]),
            (["Freund"], ["دوست"], "dust", ["Familie", "Alltag"])
        ]
        for sample in samples {
            context.insert(Card(germanTranslations: sample.de, persianTranslations: sample.fa,
                                transliteration: sample.tr, tags: sample.tags.map(tag)))
        }
        context.saveReporting()
    }
}
