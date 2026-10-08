//
//  RootView.swift
//  DariApp
//
//  Wurzel der App: die TabBar mit fuenf Bereichen (Heute, Üben, Karten,
//  Statistik, Mehr). Jeder Tab besitzt einen eigenen NavigationStack, damit
//  Navigationszustaende voneinander getrennt bleiben.
//  Beim Start wird (hoechstens einmal taeglich) ein JSON-Backup angelegt.
//

import SwiftUI
import SwiftData

struct RootView: View {

    enum AppTab: Hashable {
        case today, practice, cards, statistics, more
    }

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @State private var selection: AppTab = .today

    var body: some View {
        TabView(selection: $selection) {
            Tab("Heute", systemImage: "sun.max", value: AppTab.today) {
                NavigationStack { TodayView() }
            }
            Tab("Üben", systemImage: "brain.head.profile", value: AppTab.practice) {
                NavigationStack { PracticeHubView() }
            }
            Tab("Karten", systemImage: "rectangle.stack", value: AppTab.cards) {
                NavigationStack { CardsView() }
            }
            Tab("Statistik", systemImage: "chart.bar.xaxis", value: AppTab.statistics) {
                NavigationStack { StatisticsView() }
            }
            Tab("Mehr", systemImage: "gearshape", value: AppTab.more) {
                NavigationStack { SettingsView() }
            }
        }
        .task {
            SpeechService.shared.prepare()
            runDailyBackup()
        }
    }

    /// Taegliche, automatische JSON-Sicherung (nur, wenn es Daten gibt).
    private func runDailyBackup() {
        let safety = StoreSafety()
        guard safety.isAutoJSONDue() else { return }
        let count = (try? context.fetchCount(FetchDescriptor<Card>())) ?? 0
        guard count > 0 else { return }
        if let data = try? BackupService(context: context, settings: settings).makeBackup(includeAudio: false) {
            _ = try? safety.writeJSONBackup(data, reason: "auto")
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .environment(AppHealth.shared)
        .modelContainer(PreviewData.container)
}
