//
//  LearnSessionView.swift
//  DariApp
//
//  Container einer laufenden Lern-Session. Baut das ViewModel auf, zeigt
//  Fortschritt und den passenden Modus (Umdrehen / Multiple Choice /
//  Schreiben) und schliesst mit einer Zusammenfassung ab.
//

import SwiftUI
import SwiftData

struct LearnSessionView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let configuration: LearnSessionViewModel.Configuration
    let candidates: [Card]
    let allCards: [Card]

    @State private var viewModel: LearnSessionViewModel?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if let viewModel {
                if viewModel.isFinished {
                    SessionSummaryView(
                        answered: viewModel.answeredCount,
                        correct: viewModel.correctCount,
                        xp: viewModel.xpGained,
                        weakFixed: viewModel.weakFixed,
                        onFinish: { dismiss() }
                    )
                    .transition(.opacity)
                } else {
                    content(viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Lernen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Beenden") { dismiss() }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = LearnSessionViewModel(
                    config: configuration,
                    candidates: candidates,
                    allCards: allCards,
                    context: context
                )
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: LearnSessionViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            ProgressView(value: vm.progress)
                .tint(Palette.sage)
                .padding(.horizontal, Spacing.md)

            if vm.isRetry {
                Label("Noch einmal üben", systemImage: "arrow.counterclockwise")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: 0)

            switch vm.config.mode {
            case .flip:
                FlipModeView(viewModel: vm)
            case .multipleChoice:
                MultipleChoiceView(viewModel: vm)
            case .writing:
                WritingModeView(viewModel: vm)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.md)
        .dariAnimation(Motion.standard, value: vm.index)
    }
}

// MARK: - Zusammenfassung

private struct SessionSummaryView: View {
    let answered: Int
    let correct: Int
    let xp: Int
    let weakFixed: Int
    let onFinish: () -> Void

    private var rate: Int {
        answered == 0 ? 0 : Int((Double(correct) / Double(answered) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.sage)
            Text("Session abgeschlossen")
                .font(DariFont.title)
                .foregroundStyle(Palette.textPrimary)
            VStack(spacing: Spacing.xs) {
                Text("\(answered) Antworten")
                Text("\(correct) richtig · \(rate)% Quote · +\(xp) XP")
                    .foregroundStyle(Palette.textSecondary)
                if weakFixed > 0 {
                    Text("\(weakFixed) schwierige\(weakFixed == 1 ? "s Wort" : " Wörter") richtig beantwortet – stark!")
                        .font(DariFont.caption)
                        .foregroundStyle(Palette.sage)
                }
            }
            .font(DariFont.body)
            Button("Fertig", action: onFinish)
                .buttonStyle(.dariPrimary)
                .frame(maxWidth: 220)
        }
        .padding(Spacing.xl)
    }
}
