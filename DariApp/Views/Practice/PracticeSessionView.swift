//
//  PracticeSessionView.swift
//  DariApp
//
//  Container und Ansicht einer Uebungseinheit mit allen Aufgabentypen:
//  Auswahl, Schreiben, Zuordnung, Hoeren, Luecke, Satzbildung, Uebersetzen,
//  Grammatik und Aussprache. Persische Texte werden durchgehend rechts-nach-links
//  dargestellt.
//

import SwiftUI
import SwiftData

// MARK: - Plan

/// Beschreibt, welche Einheit gestartet werden soll (die Aufgaben entstehen erst beim Start).
enum PracticePlan: Hashable, Identifiable {
    case weak, match, listen, cloze, build, translate, speak, mix
    case grammar(language: ExerciseLanguage, topic: String?)

    var id: String {
        switch self {
        case .grammar(let language, let topic): return "grammar-\(language.rawValue)-\(topic ?? "all")"
        default: return String(describing: self)
        }
    }

    var title: String {
        switch self {
        case .weak: return "Schwierige Wörter"
        case .match: return "Zuordnung"
        case .listen: return "Hören"
        case .cloze: return "Lückentext"
        case .build: return "Satzbildung"
        case .translate: return "Übersetzen"
        case .speak: return "Aussprache"
        case .mix: return "5-Minuten-Spiel"
        case .grammar: return "Grammatik"
        }
    }
}

struct PracticeLaunch: Identifiable, Hashable {
    let id = UUID()
    let plan: PracticePlan
    let direction: QueryDirection
}

// MARK: - Container

struct PracticeSessionContainer: View {

    let launch: PracticeLaunch

    @Environment(\.modelContext) private var context
    @Query private var cards: [Card]
    @Query private var stats: [ItemStat]
    @Query private var logs: [ReviewLog]
    @State private var viewModel: PracticeSessionViewModel?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if let viewModel {
                PracticeSessionView(viewModel: viewModel, totalXP: totalXP, onRestart: restart)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(launch.plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if viewModel == nil { start() } }
    }

    private var totalXP: Int { logs.reduce(0) { $0 + Gamification.xp(for: $1) } }

    private func buildSteps() -> [PracticeStep] {
        var factory = ExerciseFactory(rng: SystemRandomNumberGenerator())
        let statMap = Dictionary(stats.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        let speech = SpeechService.shared
        let active = cards.filter(\.isActive)
        switch launch.plan {
        case .weak: return factory.planWeak(cards: cards, direction: launch.direction)
        case .match: return factory.planMatch(cards: active, rounds: 3, direction: launch.direction)
        case .listen:
            return factory.planListen(
                cards: active, direction: launch.direction, count: 10,
                canSpeakPersian: speech.canSpeak(.persian), canSpeakGerman: speech.canSpeak(.german))
        case .cloze: return factory.planCloze(cards: cards, stats: statMap, count: 10, direction: launch.direction)
        case .build: return factory.planSentences(.build, stats: statMap, count: 8, direction: launch.direction)
        case .translate: return factory.planSentences(.translate, stats: statMap, count: 8, direction: launch.direction)
        case .speak: return factory.planSpeak(cards: cards, count: 8)
        case .mix:
            return factory.planMix(
                cards: cards, stats: statMap, direction: launch.direction,
                canSpeakPersian: speech.canSpeak(.persian), canSpeakGerman: speech.canSpeak(.german))
        case .grammar(let language, let topic):
            return factory.planGrammar(language: language, topic: topic, stats: statMap, count: 10)
        }
    }

    private func start() {
        viewModel = PracticeSessionViewModel(
            title: launch.plan.title, steps: buildSteps(), cards: cards, context: context,
            regenerate: { buildSteps() })
    }

    private func restart() {
        viewModel?.leave()
        start()
    }
}

// MARK: - Session

struct PracticeSessionView: View {

    @Bindable var viewModel: PracticeSessionViewModel
    let totalXP: Int
    let onRestart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if viewModel.isFinished {
                summary
            } else {
                VStack(spacing: Spacing.md) {
                    ProgressView(value: viewModel.progress)
                        .tint(Palette.sage)
                        .padding(.horizontal, Spacing.md)
                    ScrollView {
                        stepBody
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.xl)
                            .id(viewModel.index)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.isFinished ? "Schließen" : "Beenden") {
                    if viewModel.isFinished || viewModel.answeredCount == 0 {
                        viewModel.leave(); dismiss()
                    } else {
                        viewModel.finishEarly()
                    }
                }
            }
        }
    }

    // MARK: Aufgaben

    @ViewBuilder
    private var stepBody: some View {
        if let step = viewModel.current {
            VStack(spacing: Spacing.lg) {
                if step.isRetry {
                    Label("Noch einmal üben", systemImage: "arrow.counterclockwise")
                        .font(DariFont.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                switch step.kind {
                case .choice(let id, let direction):
                    if let card = viewModel.cardByID(id) { ChoiceStepView(viewModel: viewModel, card: card, direction: direction) }
                case .write(let id, let direction):
                    if let card = viewModel.cardByID(id) { WriteStepView(viewModel: viewModel, card: card, direction: direction) }
                case .match:
                    MatchStepView(viewModel: viewModel)
                case .listen:
                    ListenStepView(viewModel: viewModel)
                case .cloze, .cardCloze:
                    ClozeStepView(viewModel: viewModel)
                case .build:
                    BuildStepView(viewModel: viewModel)
                case .translate:
                    TranslateStepView(viewModel: viewModel)
                case .grammar:
                    GrammarStepView(viewModel: viewModel)
                case .speak(let id):
                    if let card = viewModel.cardByID(id) { SpeakStepView(viewModel: viewModel, card: card) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Abschluss

    private var summary: some View {
        let rate = viewModel.answeredCount == 0 ? 0 : Int((Double(viewModel.correctCount) / Double(viewModel.answeredCount) * 100).rounded())
        let before = Gamification.level(forXP: totalXP - viewModel.xpGained)
        let after = Gamification.level(forXP: totalXP)
        return ScrollView {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.sage)
                Text("\(viewModel.title) abgeschlossen")
                    .font(DariFont.title)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textPrimary)
                HStack(spacing: Spacing.sm) {
                    SummaryTile(value: "\(viewModel.answeredCount)", label: "Antworten")
                    SummaryTile(value: "\(rate)%", label: "richtig")
                    SummaryTile(value: "+\(viewModel.xpGained)", label: "XP")
                }
                if after.level > before.level {
                    Label("Level \(after.level) erreicht!", systemImage: "arrow.up.circle.fill")
                        .font(DariFont.headline)
                        .foregroundStyle(Palette.turquoise)
                }
                if viewModel.weakFixed > 0 {
                    Text("\(viewModel.weakFixed) schwierige\(viewModel.weakFixed == 1 ? "s Wort" : " Wörter") richtig beantwortet – stark!")
                        .font(DariFont.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: Spacing.sm) {
                    if viewModel.canRestart && viewModel.answeredCount > 0 {
                        Button("Noch eine Runde") { onRestart() }
                            .buttonStyle(.dariPrimary)
                    }
                    Button("Fertig") { viewModel.leave(); dismiss() }
                        .buttonStyle(.dariSecondary)
                }
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.lg)
        }
    }
}

private struct SummaryTile: View {
    let value: String
    let label: String
    var body: some View {
        CardSurface(padding: Spacing.sm) {
            VStack(spacing: 2) {
                Text(value).font(DariFont.title).foregroundStyle(Palette.textPrimary)
                Text(label).font(DariFont.caption).foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Gemeinsame Bausteine

private func layoutDirection(_ persian: Bool) -> LayoutDirection { persian ? .rightToLeft : .leftToRight }

private struct PromptCard: View {
    let text: String
    let persian: Bool
    var minHeight: CGFloat = 110

    var body: some View {
        CardSurface(padding: Spacing.lg, cornerRadius: CornerRadius.lg) {
            Text(text)
                .font(persian ? DariFont.learnTermPersian : DariFont.learnTermGerman)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .environment(\.layoutDirection, layoutDirection(persian))
        }
    }
}

private struct OptionList: View {
    let choices: ChoiceSet
    let selected: Int?
    let persian: Bool
    let onPick: (Int) -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(choices.options.enumerated()), id: \.offset) { pair in
                Button { onPick(pair.offset) } label: {
                    Text(pair.element)
                        .font(persian ? .system(size: 24) : DariFont.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .environment(\.layoutDirection, layoutDirection(persian))
                }
                .buttonStyle(ChoiceButtonStyle(state: state(pair.offset)))
                .disabled(selected != nil)
            }
        }
    }

    private func state(_ i: Int) -> ChoiceButtonStyle.SelectionState {
        guard let selected else { return .neutral }
        if i == choices.correctIndex { return .correct }
        if i == selected { return .wrong }
        return .dimmed
    }
}

private struct QualityBanner: View {
    let quality: AnswerQuality
    var body: some View {
        switch quality {
        case .perfect: Label("Perfekt!", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.success)
        case .typo: Label("Fast – kleiner Tippfehler", systemImage: "exclamationmark.circle.fill").foregroundStyle(Palette.warning)
        case .wrong: Label("Leider falsch", systemImage: "xmark.circle.fill").foregroundStyle(Palette.error)
        }
    }
}

private struct NextButton: View {
    let viewModel: PracticeSessionViewModel
    var body: some View {
        Button("Weiter") { viewModel.next() }
            .buttonStyle(.dariPrimary)
            .accessibilityIdentifier("practice.next")
    }
}

/// Texteingabe (Schreiben/Uebersetzen) mit passender Richtung.
private struct AnswerField: View {
    @Bindable var viewModel: PracticeSessionViewModel
    let persian: Bool
    @FocusState private var focused: Bool

    var body: some View {
        TextField(persian ? "پاسخ فارسی" : "Antwort", text: $viewModel.state.input)
            .focused($focused)
            .font(persian ? .system(size: 24) : DariFont.headline)
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, layoutDirection(persian))
            .autocorrectionDisabled(persian)
            .textInputAutocapitalization(persian ? .never : .sentences)
            .submitLabel(.done)
            .padding(Spacing.md)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .disabled(viewModel.state.quality != nil)
            .onSubmit { viewModel.submitText() }
            .onAppear { focused = true }
            .accessibilityIdentifier("practice.input")
    }
}

// MARK: - Auswahl

private struct ChoiceStepView: View {
    let viewModel: PracticeSessionViewModel
    let card: Card
    let direction: ResolvedDirection

    var body: some View {
        VStack(spacing: Spacing.lg) {
            PromptCard(
                text: direction == .germanToPersian ? card.primaryGerman : card.primaryPersian,
                persian: direction == .persianToGerman)
            if let choices = viewModel.state.choices {
                OptionList(choices: choices, selected: viewModel.state.selected,
                           persian: direction == .germanToPersian) { viewModel.choose($0) }
            }
            if viewModel.state.selected != nil { NextButton(viewModel: viewModel) }
        }
    }
}

// MARK: - Schreiben

private struct WriteStepView: View {
    let viewModel: PracticeSessionViewModel
    let card: Card
    let direction: ResolvedDirection

    var body: some View {
        let answerPersian = direction == .germanToPersian
        VStack(spacing: Spacing.lg) {
            PromptCard(text: answerPersian ? card.primaryGerman : card.primaryPersian, persian: !answerPersian, minHeight: 90)
            AnswerField(viewModel: viewModel, persian: answerPersian)
            if let quality = viewModel.state.quality {
                VStack(spacing: Spacing.xs) {
                    QualityBanner(quality: quality).font(DariFont.headline)
                    if quality != .perfect {
                        Text("Richtig: \(answerPersian ? card.primaryPersian : card.primaryGerman)")
                            .font(DariFont.body)
                            .foregroundStyle(Palette.textSecondary)
                            .environment(\.layoutDirection, layoutDirection(answerPersian))
                    }
                }
                NextButton(viewModel: viewModel)
            } else {
                Button("Prüfen") { viewModel.submitText() }
                    .buttonStyle(.dariPrimary)
                    .disabled(viewModel.state.input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Hoeren

private struct ListenStepView: View {
    let viewModel: PracticeSessionViewModel

    var body: some View {
        if let data = viewModel.state.listen {
            VStack(spacing: Spacing.lg) {
                Text(data.spoken == .persian ? "Persisch hören → Deutsch wählen" : "Deutsch hören → Persisch wählen")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                Button { viewModel.playListening() } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(Palette.turquoise)
                        .clipShape(Circle())
                        .dariShadow()
                }
                .accessibilityLabel("Noch einmal abspielen")
                OptionList(choices: data.choices, selected: viewModel.state.selected,
                           persian: data.answerLanguage == .persian) { viewModel.choose($0) }
                if viewModel.state.selected != nil {
                    CardSurface {
                        VStack(spacing: Spacing.xs) {
                            Text(data.speakText)
                                .font(data.spoken == .persian ? DariFont.learnTermPersian : DariFont.learnTermGerman)
                                .environment(\.layoutDirection, layoutDirection(data.spoken == .persian))
                            if let card = viewModel.cardByID(data.cardID), !card.transliteration.isEmpty, data.spoken == .persian {
                                Text(card.transliteration).font(DariFont.transliteration).foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    NextButton(viewModel: viewModel)
                }
            }
            .task(id: viewModel.index) {
                try? await Task.sleep(for: .milliseconds(350))
                viewModel.playListening()
            }
        }
    }
}

// MARK: - Zuordnung

private struct MatchStepView: View {
    let viewModel: PracticeSessionViewModel

    var body: some View {
        if let match = viewModel.state.match {
            let leftPersian = match.round.direction == .persianToGerman
            VStack(spacing: Spacing.lg) {
                Text("Tippe zwei Wörter an, die zusammengehören")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                HStack(alignment: .top, spacing: Spacing.sm) {
                    column(match.round.left, persian: leftPersian, selected: match.selectedLeft, side: .left, match: match)
                    column(match.round.right, persian: !leftPersian, selected: match.selectedRight, side: .right, match: match)
                }
                if match.finished {
                    CardSurface {
                        VStack(spacing: Spacing.xs) {
                            Label(match.errors == 0 ? "Fehlerfrei!" : "\(match.errors) Fehlversuch\(match.errors == 1 ? "" : "e")",
                                  systemImage: match.errors == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(DariFont.headline)
                                .foregroundStyle(match.errors == 0 ? Palette.success : Palette.warning)
                            Text("Falsch zugeordnete Wörter kommen bald wieder dran.")
                                .font(DariFont.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    NextButton(viewModel: viewModel)
                }
            }
        }
    }

    private enum Side { case left, right }

    private func column(_ ids: [UUID], persian: Bool, selected: UUID?, side: Side, match: MatchState) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(ids, id: \.self) { id in
                let card = viewModel.cardByID(id)
                let text = persian ? (card?.primaryPersian ?? "") : (card?.primaryGerman ?? "")
                let isDone = match.done.contains(id)
                let isShaking = (side == .left && match.shake?.left == id) || (side == .right && match.shake?.right == id)
                Button {
                    if side == .left { viewModel.pickMatch(left: id) } else { viewModel.pickMatch(right: id) }
                    if viewModel.state.match?.shake != nil {
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            viewModel.clearShake()
                        }
                    }
                } label: {
                    Text(text)
                        .font(persian ? .system(size: 22) : DariFont.body)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .padding(.horizontal, Spacing.xs)
                        .environment(\.layoutDirection, layoutDirection(persian))
                }
                .buttonStyle(MatchButtonStyle(isSelected: selected == id, isDone: isDone, isWrong: isShaking))
                .disabled(isDone)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MatchButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isDone: Bool
    let isWrong: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isDone ? Color.white : Palette.textPrimary)
            .background(isDone ? Palette.sage : (isSelected ? Palette.sage.opacity(0.18) : Palette.surface))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .strokeBorder(isWrong ? Palette.error : (isSelected ? Palette.sage : Palette.separator), lineWidth: isSelected || isWrong ? 2 : 1)
            )
            .opacity(isDone ? 0.4 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// MARK: - Lueckentext

private struct ClozeStepView: View {
    let viewModel: PracticeSessionViewModel

    var body: some View {
        if let cloze = viewModel.state.cloze {
            let persian = cloze.language == .persian
            let answered = viewModel.state.selected != nil
            VStack(spacing: Spacing.lg) {
                Text("Welches Wort fehlt?")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                CardSurface(padding: Spacing.lg, cornerRadius: CornerRadius.lg) {
                    FlowLayout(spacing: Spacing.xs, rtl: persian) {
                        ForEach(Array(cloze.tokens.enumerated()), id: \.offset) { pair in
                            if let word = pair.element {
                                Text(word)
                            } else {
                                gap(cloze: cloze, answered: answered)
                                if !cloze.trail.isEmpty { Text(cloze.trail) }
                            }
                        }
                    }
                    .font(.system(size: persian ? 30 : 26, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: persian ? .trailing : .leading)
                }
                Text(cloze.hint)
                    .font(DariFont.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, layoutDirection(cloze.hintLanguage == .persian))
                OptionList(choices: cloze.choices, selected: viewModel.state.selected, persian: persian) { viewModel.choose($0) }
                if answered {
                    CardSurface {
                        VStack(spacing: Spacing.xs) {
                            Label(viewModel.state.quality == .perfect ? "Richtig!" : "Leider falsch",
                                  systemImage: viewModel.state.quality == .perfect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(DariFont.headline)
                                .foregroundStyle(viewModel.state.quality == .perfect ? Palette.success : Palette.error)
                            Text(cloze.full)
                                .font(persian ? .system(size: 24) : DariFont.body)
                                .multilineTextAlignment(.center)
                                .environment(\.layoutDirection, layoutDirection(persian))
                            if !cloze.transliteration.isEmpty {
                                Text(cloze.transliteration).font(DariFont.transliteration).foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    NextButton(viewModel: viewModel)
                }
            }
        }
    }

    private func gap(cloze: ClozeData, answered: Bool) -> some View {
        let text: String = answered
            ? (viewModel.state.quality == .perfect ? cloze.answer : cloze.choices.options[viewModel.state.selected ?? 0])
            : "      "
        let color: Color = answered ? (viewModel.state.quality == .perfect ? Palette.success : Palette.error) : Palette.sage
        return Text(text)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(color).frame(height: 3) }
    }
}

// MARK: - Satzbildung

private struct BuildStepView: View {
    let viewModel: PracticeSessionViewModel

    var body: some View {
        if let build = viewModel.state.build {
            let persian = build.answerLanguage == .persian
            let result = viewModel.state.buildCorrect
            VStack(spacing: Spacing.lg) {
                Text("Bilde den Satz")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                CardSurface(padding: Spacing.lg, cornerRadius: CornerRadius.lg) {
                    Text(build.prompt)
                        .font(build.promptLanguage == .persian ? .system(size: 28) : DariFont.title)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .environment(\.layoutDirection, layoutDirection(build.promptLanguage == .persian))
                }
                // Gelegte Woerter
                FlowLayout(spacing: Spacing.xs, rtl: persian) {
                    ForEach(viewModel.state.placed, id: \.self) { position in
                        Button { viewModel.unplace(position) } label: {
                            tokenLabel(build.tokens[position].text, persian: persian, tint: result == nil ? nil : (result == true ? Palette.success : Palette.error))
                        }
                    }
                    if viewModel.state.placed.isEmpty {
                        Text("Tippe die Wörter in der richtigen Reihenfolge an")
                            .font(DariFont.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: persian ? .trailing : .leading)
                .background(Palette.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

                // Wortvorrat
                FlowLayout(spacing: Spacing.xs, rtl: persian) {
                    ForEach(Array(build.tokens.enumerated()), id: \.offset) { pair in
                        Button { viewModel.place(pair.offset) } label: {
                            tokenLabel(pair.element.text, persian: persian, tint: nil)
                        }
                        .opacity(viewModel.state.placed.contains(pair.offset) ? 0.25 : 1)
                        .disabled(viewModel.state.placed.contains(pair.offset) || result != nil)
                    }
                }
                .frame(maxWidth: .infinity)

                if let result {
                    CardSurface {
                        VStack(spacing: Spacing.xs) {
                            Label(result ? "Richtig!" : "Leider falsch", systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(DariFont.headline)
                                .foregroundStyle(result ? Palette.success : Palette.error)
                            Text(build.full)
                                .font(persian ? .system(size: 24) : DariFont.body)
                                .multilineTextAlignment(.center)
                                .environment(\.layoutDirection, layoutDirection(persian))
                            Text(build.transliteration).font(DariFont.transliteration).foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    NextButton(viewModel: viewModel)
                } else {
                    HStack(spacing: Spacing.sm) {
                        Button("Zurücksetzen") { viewModel.resetBuild() }.buttonStyle(.dariSecondary)
                        Button("Prüfen") { viewModel.checkBuild() }
                            .buttonStyle(.dariPrimary)
                            .disabled(viewModel.state.placed.count != build.tokens.count)
                            .accessibilityIdentifier("practice.check")
                    }
                }
            }
        }
    }

    private func tokenLabel(_ text: String, persian: Bool, tint: Color?) -> some View {
        Text(text)
            .font(.system(size: persian ? 23 : 19))
            .foregroundStyle(tint == nil ? Palette.textPrimary : .white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(tint ?? Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous).strokeBorder(Palette.separator, lineWidth: tint == nil ? 1 : 0))
    }
}

// MARK: - Uebersetzen

private struct TranslateStepView: View {
    let viewModel: PracticeSessionViewModel

    var body: some View {
        if let data = viewModel.state.translate {
            let persian = data.answerLanguage == .persian
            VStack(spacing: Spacing.lg) {
                Text("Übersetze den Satz")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                CardSurface(padding: Spacing.lg, cornerRadius: CornerRadius.lg) {
                    Text(data.prompt)
                        .font(data.promptLanguage == .persian ? .system(size: 28) : DariFont.title)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .environment(\.layoutDirection, layoutDirection(data.promptLanguage == .persian))
                }
                AnswerField(viewModel: viewModel, persian: persian)
                if let quality = viewModel.state.quality {
                    VStack(spacing: Spacing.xs) {
                        QualityBanner(quality: quality).font(DariFont.headline)
                        if quality != .perfect {
                            Text("Richtig: \(data.solutions[0])")
                                .font(persian ? .system(size: 22) : DariFont.body)
                                .foregroundStyle(Palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .environment(\.layoutDirection, layoutDirection(persian))
                        }
                        Text(data.transliteration).font(DariFont.transliteration).foregroundStyle(Palette.textSecondary)
                    }
                    NextButton(viewModel: viewModel)
                } else {
                    Button("Prüfen") { viewModel.submitText() }
                        .buttonStyle(.dariPrimary)
                        .disabled(viewModel.state.input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Grammatik

private struct GrammarStepView: View {
    let viewModel: PracticeSessionViewModel

    var body: some View {
        if let question = viewModel.state.grammar {
            let answered = viewModel.state.selected != nil
            VStack(spacing: Spacing.lg) {
                Text("\(question.language == .persian ? "Persisch" : "Deutsch") · \(question.topic)")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                CardSurface(padding: Spacing.lg, cornerRadius: CornerRadius.lg) {
                    Text(question.question)
                        .font(.system(size: 21, weight: .medium))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .environment(\.layoutDirection, containsPersian(question.question) && startsPersian(question.question) ? .rightToLeft : .leftToRight)
                }
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(question.choices.options.enumerated()), id: \.offset) { pair in
                        let persian = containsPersian(pair.element)
                        Button { viewModel.choose(pair.offset) } label: {
                            Text(pair.element)
                                .font(persian ? .system(size: 22) : DariFont.body)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .multilineTextAlignment(.center)
                                .environment(\.layoutDirection, persian && startsPersian(pair.element) ? .rightToLeft : .leftToRight)
                        }
                        .buttonStyle(ChoiceButtonStyle(state: optionState(pair.offset, question: question)))
                        .disabled(answered)
                    }
                }
                if answered {
                    CardSurface {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label(viewModel.state.quality == .perfect ? "Richtig!" : "Leider falsch",
                                  systemImage: viewModel.state.quality == .perfect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(DariFont.headline)
                                .foregroundStyle(viewModel.state.quality == .perfect ? Palette.success : Palette.error)
                            Text(question.explanation).font(DariFont.body).foregroundStyle(Palette.textSecondary)
                            if !question.explanationPersian.isEmpty {
                                Text(question.explanationPersian)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Palette.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                            }
                        }
                    }
                    NextButton(viewModel: viewModel)
                }
            }
        }
    }

    private func optionState(_ i: Int, question: GrammarQuestion) -> ChoiceButtonStyle.SelectionState {
        guard let selected = viewModel.state.selected else { return .neutral }
        if i == question.choices.correctIndex { return .correct }
        if i == selected { return .wrong }
        return .dimmed
    }

    private func containsPersian(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
    }

    /// Erstes „starkes" Zeichen persisch? Dann ist der Satz insgesamt rechts-nach-links.
    private func startsPersian(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if (0x0600...0x06FF).contains(scalar.value) { return true }
            if scalar.properties.isAlphabetic { return false }
        }
        return false
    }
}

// MARK: - Aussprache

private struct SpeakStepView: View {
    let viewModel: PracticeSessionViewModel
    let card: Card

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Hören · Nachsprechen · Vergleichen")
                .font(DariFont.caption)
                .foregroundStyle(Palette.textSecondary)
            CardSurface(padding: Spacing.lg, cornerRadius: CornerRadius.lg) {
                VStack(spacing: Spacing.xs) {
                    Text(card.primaryPersian)
                        .font(DariFont.learnTermPersian)
                        .environment(\.layoutDirection, .rightToLeft)
                    if !card.transliteration.isEmpty {
                        Text(card.transliteration).font(DariFont.transliteration).foregroundStyle(Palette.textSecondary)
                    }
                    Text(card.primaryGerman).font(DariFont.body).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: Spacing.lg) {
                roundButton("play.fill", "Vorbild", tint: Palette.turquoise) { viewModel.playReference(for: card.id) }
                roundButton(viewModel.state.isRecording ? "stop.fill" : "mic.fill",
                            viewModel.state.isRecording ? "Aufnahme läuft …" : "Aufnehmen",
                            tint: viewModel.state.isRecording ? Palette.terracotta : Palette.sage) {
                    Task { await viewModel.toggleRecording() }
                }
                if viewModel.state.recordedFile != nil && !viewModel.state.isRecording {
                    roundButton("play.circle.fill", "Meine", tint: Palette.sage) { viewModel.playRecording() }
                }
            }
            if viewModel.state.recordedFile != nil && !viewModel.state.isRecording {
                HStack(spacing: Spacing.sm) {
                    Button("Nochmal üben") { viewModel.rateSpeaking(good: false) }.buttonStyle(.dariSecondary(tint: Palette.terracotta))
                    Button("Klingt gut") { viewModel.rateSpeaking(good: true) }.buttonStyle(.dariPrimary)
                }
            }
            Text("Du vergleichst selbst – ZARA bewertet die Aussprache nicht automatisch.")
                .font(DariFont.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func roundButton(_ icon: String, _ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: Spacing.xxs) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(tint)
                    .clipShape(Circle())
                    .dariShadow(.subtle)
            }
            Text(label).font(DariFont.caption).foregroundStyle(Palette.textSecondary)
        }
    }
}
