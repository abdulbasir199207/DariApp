//
//  PreviewData.swift
//  DariApp
//
//  Stellt einen In-Memory-Container mit Beispielkarten fuer SwiftUI-Previews
//  bereit. Nur fuer Entwicklung/Previews gedacht, nie in Produktion genutzt.
//

import Foundation
import SwiftData

@MainActor
enum PreviewData {

    /// Vorbefuellter Container fuer Previews.
    static let container: ModelContainer = {
        let container = ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let tagFamilie = Tag(name: "Familie")
        let tagAlltag = Tag(name: "Alltag")
        let tagVerben = Tag(name: "Verben")
        [tagFamilie, tagAlltag, tagVerben].forEach { context.insert($0) }

        let samples: [(de: [String], fa: [String], tr: String, tags: [Tag])] = [
            (["Haus", "Gebäude"], ["خانه", "منزل"], "khâne", [tagAlltag]),
            (["Mutter"], ["مادر"], "mâdar", [tagFamilie]),
            (["Vater"], ["پدر"], "pedar", [tagFamilie]),
            (["Wasser"], ["آب"], "âb", [tagAlltag]),
            (["gehen"], ["رفتن"], "raftan", [tagVerben]),
            (["essen"], ["خوردن"], "khordan", [tagVerben]),
            (["Brot"], ["نان"], "nân", [tagAlltag]),
            (["Freund"], ["دوست"], "dust", [tagFamilie, tagAlltag])
        ]

        for sample in samples {
            let card = Card(
                germanTranslations: sample.de,
                persianTranslations: sample.fa,
                transliteration: sample.tr,
                tags: sample.tags
            )
            context.insert(card)
        }

        try? context.save()
        return container
    }()
}
