//
//  FlipModeView.swift
//  DariApp
//
//  Modus 1 – Karte umdrehen. Eine Seite wird gezeigt; Antippen dreht die
//  Karte (3D-Flip). Nach dem Aufdecken bewertet der Nutzer per FSRS-Buttons.
//

import SwiftUI

struct FlipModeView: View {
    let viewModel: LearnSessionViewModel

    @Environment(\.animationsEnabled) private var animationsEnabled
    @State private var audio = AudioRecorder()

    var body: some View {
        VStack(spacing: Spacing.xl) {
            flipCard
            controls
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Karte

    private var flipCard: some View {
        ZStack {
            if viewModel.isFlipped {
                face(
                    text: viewModel.answerText,
                    isPersian: viewModel.answerIsPersian,
                    showExtras: true
                )
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                face(
                    text: viewModel.promptText,
                    isPersian: viewModel.promptIsPersian,
                    showExtras: false
                )
            }
        }
        .rotation3DEffect(.degrees(viewModel.isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .dariAnimation(Motion.flip, value: viewModel.isFlipped)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            viewModel.flip()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Zum Umdrehen doppeltippen")
    }

    private func face(text: String, isPersian: Bool, showExtras: Bool) -> some View {
        CardSurface(padding: Spacing.xl, cornerRadius: CornerRadius.lg) {
            VStack(spacing: Spacing.md) {
                Text(text.isEmpty ? "—" : text)
                    .font(isPersian ? DariFont.learnTermPersian : DariFont.learnTermGerman)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, isPersian ? .rightToLeft : .leftToRight)

                if showExtras, let card = viewModel.currentCard {
                    if !card.transliteration.isEmpty {
                        Text(card.transliteration)
                            .font(DariFont.transliteration)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let name = card.audioFileName {
                        Button {
                            audio.play(fileName: name)
                        } label: {
                            Image(systemName: "speaker.wave.2.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Palette.turquoise)
                        }
                        .accessibilityLabel("Aussprache abspielen")
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    // MARK: - Steuerung

    @ViewBuilder
    private var controls: some View {
        if viewModel.isFlipped {
            RatingButtons { rating in
                Haptics.tap()
                viewModel.rate(rating)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Text("Zum Umdrehen tippen")
                .font(DariFont.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

/// Vier FSRS-Bewertungsknoepfe (Nochmal / Schwer / Gut / Leicht).
struct RatingButtons: View {
    let onRate: (FSRSRating) -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            button("Nochmal", .again, Palette.terracotta)
            button("Schwer", .hard, Palette.warning)
            button("Gut", .good, Palette.sage)
            button("Leicht", .easy, Palette.turquoise)
        }
    }

    private func button(_ title: String, _ rating: FSRSRating, _ color: Color) -> some View {
        Button { onRate(rating) } label: {
            Text(title)
                .font(DariFont.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .foregroundStyle(.white)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
        }
    }
}
