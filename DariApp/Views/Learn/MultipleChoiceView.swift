//
//  MultipleChoiceView.swift
//  DariApp
//
//  Modus 2 – Multiple Choice. Eine Seite wird gezeigt, vier Optionen stehen
//  zur Wahl. Nach der Auswahl faerbt sich die richtige (und ggf. die falsch
//  gewaehlte) Option ein, danach geht es weiter.
//

import SwiftUI

struct MultipleChoiceView: View {
    let viewModel: LearnSessionViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            prompt
            options
            if viewModel.selectedChoiceIndex != nil {
                Button("Weiter") { viewModel.continueAfterFeedback() }
                    .buttonStyle(.dariPrimary)
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private var prompt: some View {
        CardSurface(padding: Spacing.xl, cornerRadius: CornerRadius.lg) {
            Text(viewModel.promptText)
                .font(viewModel.promptIsPersian ? DariFont.learnTermPersian : DariFont.learnTermGerman)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 120)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, viewModel.promptIsPersian ? .rightToLeft : .leftToRight)
        }
    }

    private var options: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(viewModel.choices.enumerated()), id: \.offset) { pair in
                let index = pair.offset
                Button {
                    viewModel.selectChoice(index)
                    if let q = viewModel.lastQuality { Haptics.feedback(for: q) }
                } label: {
                    Text(pair.element)
                        .font(viewModel.answerIsPersian ? .system(size: 24) : DariFont.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .environment(\.layoutDirection, viewModel.answerIsPersian ? .rightToLeft : .leftToRight)
                }
                .buttonStyle(ChoiceButtonStyle(state: state(for: index)))
                .disabled(viewModel.selectedChoiceIndex != nil)
            }
        }
    }

    private func state(for index: Int) -> ChoiceButtonStyle.SelectionState {
        guard let selected = viewModel.selectedChoiceIndex else { return .neutral }
        if index == viewModel.correctChoiceIndex { return .correct }
        if index == selected { return .wrong }
        return .dimmed
    }
}

/// Buttonstil fuer Multiple-Choice-Optionen mit Feedback-Faerbung.
struct ChoiceButtonStyle: ButtonStyle {
    enum SelectionState { case neutral, correct, wrong, dimmed }
    let state: SelectionState

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(Spacing.md)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .opacity(state == .dimmed ? 0.5 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var foreground: Color {
        switch state {
        case .correct, .wrong: return .white
        default: return Palette.textPrimary
        }
    }

    private var background: Color {
        switch state {
        case .neutral, .dimmed: return Palette.surface
        case .correct: return Palette.success
        case .wrong: return Palette.error
        }
    }

    private var border: Color {
        state == .neutral ? Palette.separator : .clear
    }
}
