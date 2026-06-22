import SwiftUI

/// The full daily drill: three escalating 20-second rounds. Big tappable choices, instant feedback,
/// a per-round countdown, and a short hand-off card between rounds. On completion, records the
/// result and presents ResultView.
struct DrillView: View {
    let tier: Tier
    let rounds: [[Problem]]
    var onFinished: (DailyResult) -> Void

    @EnvironmentObject var appModel: AppModel
    @AppStorage("quickmath.haptics") private var hapticsEnabled = true
    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = DrillEngine()
    @State private var feedback: Int?            // value tapped, for the flash
    @State private var locked = false            // brief input lock during feedback flash
    @State private var finishedResult: DailyResult?

    var body: some View {
        ZStack {
            QMBackground()
            switch engine.phase {
            case .idle, .playing:
                playingView
            case .betweenRounds:
                betweenRoundsView
            case .done:
                Color.clear
            }
        }
        .fullScreenCover(item: $finishedResult, onDismiss: { dismiss() }) { result in
            ResultView(result: result)
        }
        .onAppear {
            engine.hapticsEnabled = hapticsEnabled
            engine.onComplete = { tally, tier in
                let result = tally.makeResult(tier: tier)
                appModel.recordDrill(tally, tier: tier)
                onFinished(result)
                finishedResult = result
            }
            engine.start(rounds: rounds, tier: tier)
        }
    }

    // MARK: Playing

    private var playingView: some View {
        VStack(spacing: 0) {
            topBar
            roundHeader.padding(.top, 6)
            Spacer(minLength: 12)
            promptCard
            Spacer(minLength: 12)
            choiceGrid
            Spacer().frame(height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var topBar: some View {
        HStack {
            Button { Haptics.tap(); engine.cancel(); dismiss() } label: {
                Image(systemName: "xmark").font(.headline.weight(.semibold))
            }
            .tint(.secondary)
            .accessibilityIdentifier("drill-close")

            Spacer()

            Text("Round \(engine.roundIndex + 1) of \(engine.totalRounds)")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "timer").font(.subheadline)
                Text("\(Int(ceil(engine.timeRemaining)))")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
            }
            .foregroundStyle(engine.timeRemaining <= 5 ? Color.qmWrong : .primary)
        }
    }

    private var roundHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: engine.roundKind.systemImage)
                Text(engine.roundKind.title).font(.headline)
            }
            .foregroundStyle(Color.qmAccent)
            ProgressView(value: max(0, engine.timeRemaining), total: DrillEngine.roundSeconds)
                .tint(Color.qmAccent)
        }
    }

    private var promptCard: some View {
        VStack {
            if let p = engine.current {
                Text(p.prompt)
                    .font(p.kind == .word
                          ? .system(size: 24, weight: .semibold, design: .rounded)
                          : .system(size: 52, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, p.kind == .word ? 26 : 36)
                    .padding(.horizontal, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("prompt")
    }

    private var choiceGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(engine.current?.choices ?? [], id: \.self) { value in
                ChoiceButton(value: value, state: state(for: value)) {
                    tap(value)
                }
                .disabled(locked)
            }
        }
    }

    private func state(for value: Int) -> ChoiceButton.State {
        guard let fb = feedback, let p = engine.current else { return .normal }
        if value == p.answer { return .correct }       // always reveal the right answer
        if value == fb { return .wrong }               // and flag the wrong tap
        return .normal
    }

    private func tap(_ value: Int) {
        guard !locked, engine.current != nil else { return }
        feedback = value
        locked = true
        let correct = engine.current?.isCorrect(value) ?? false
        if hapticsEnabled { correct ? Haptics.success() : Haptics.warning() }
        // Brief flash, then advance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            feedback = nil
            locked = false
            engine.answer(value)
        }
    }

    // MARK: Between rounds

    private var betweenRoundsView: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.qmAccent)
            VStack(spacing: 6) {
                Text("Round \(engine.roundIndex) done")
                    .font(.title2.weight(.bold))
                Text("Next up: \(engine.roundKind.title)")
                    .font(.headline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Haptics.soft(); engine.continueToNextRound() } label: {
                Text("Next Round").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .accessibilityIdentifier("next-round")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
    }
}
