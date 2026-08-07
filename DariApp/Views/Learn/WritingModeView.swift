//
//  WritingModeView.swift
//  DariApp
//
//  Modus 3 – Schreiben. Eine Seite wird gezeigt, der Nutzer tippt die andere
//  Seite ein (Deutsch oder persische Schrift; niemals Lautschrift). Nach dem
//  Absenden erscheint Feedback: perfekt / kleiner Tippfehler / falsch.
//

import SwiftUI

struct WritingModeView: View {
    let viewModel: LearnSessionViewModel

    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            prompt
            inputField
            feedback
            actionButton
        }
        .padding(.horizontal, Spacing.md)
        .onChange(of: viewModel.index) { _, _ in
            input = ""
            focused = true
        }
        .onAppear { focused = true }
    }

    private var prompt: some View {
        CardSurface(padding: Spacing.xl, cornerRadius: CornerRadius.lg) {
            Text(viewModel.promptText)
                .font(viewModel.promptIsPersian ? DariFont.learnTermPersian : DariFont.learnTermGerman)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 100)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, viewModel.promptIsPersian ? .rightToLeft : .leftToRight)
        }
    }

    private var inputField: some View {
        TextField(viewModel.answerIsPersian ? "پاسخ فارسی" : "Antwort", text: $input)
            .focused($focused)
            .font(viewModel.answerIsPersian ? .system(size: 24) : DariFont.headline)
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, viewModel.answerIsPersian ? .rightToLeft : .leftToRight)
            .autocorrectionDisabled(viewModel.answerIsPersian)
            .textInputAutocapitalization(viewModel.answerIsPersian ? .never : .sentences)
            .padding(Spacing.md)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .disabled(viewModel.lastQuality != nil)
            .onSubmit(submit)
    }

    @ViewBuilder
    private var feedback: some View {
        if let quality = viewModel.lastQuality {
            VStack(spacing: Spacing.xs) {
                Label(feedbackText(quality), systemImage: feedbackIcon(quality))
                    .font(DariFont.headline)
                    .foregroundStyle(feedbackColor(quality))
                if quality != .perfect {
                    Text("Richtig: \(viewModel.answerText)")
                        .font(DariFont.body)
                        .foregroundStyle(Palette.textSecondary)
                        .environment(\.layoutDirection, viewModel.answerIsPersian ? .rightToLeft : .leftToRight)
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if viewModel.lastQuality == nil {
            Button("Pruefen", action: submit)
                .buttonStyle(.dariPrimary)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        } else {
            Button("Weiter") { viewModel.continueAfterFeedback() }
                .buttonStyle(.dariPrimary)
        }
    }

    // MARK: - Logik

    private func submit() {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        focused = false
        viewModel.submitWriting(input)
        if let q = viewModel.lastQuality { Haptics.feedback(for: q) }
    }

    private func feedbackText(_ q: AnswerQuality) -> String {
        switch q {
        case .perfect: return "Perfekt!"
        case .typo: return "Fast – kleiner Tippfehler"
        case .wrong: return "Leider falsch"
        }
    }

    private func feedbackIcon(_ q: AnswerQuality) -> String {
        switch q {
        case .perfect: return "checkmark.circle.fill"
        case .typo: return "exclamationmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }

    private func feedbackColor(_ q: AnswerQuality) -> Color {
        switch q {
        case .perfect: return Palette.success
        case .typo: return Palette.warning
        case .wrong: return Palette.error
        }
    }
}
