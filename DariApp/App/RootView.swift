//
//  RootView.swift
//  DariApp
//
//  Wurzel der App: die TabBar mit vier Bereichen. Jeder Tab besitzt einen
//  eigenen NavigationStack, damit Navigationszustaende voneinander getrennt
//  bleiben (Standardverhalten fuer TabViews).
//

import SwiftUI

struct RootView: View {

    enum AppTab: Hashable {
        case learn, cards, statistics, settings
    }

    @State private var selection: AppTab = .learn

    var body: some View {
        TabView(selection: $selection) {
            Tab("Lernen", systemImage: "brain.head.profile", value: AppTab.learn) {
                NavigationStack { LearnView() }
            }
            Tab("Karten", systemImage: "rectangle.stack", value: AppTab.cards) {
                NavigationStack { CardsView() }
            }
            Tab("Statistik", systemImage: "chart.bar.xaxis", value: AppTab.statistics) {
                NavigationStack { StatisticsView() }
            }
            Tab("Einstellungen", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .modelContainer(PreviewData.container)
}
