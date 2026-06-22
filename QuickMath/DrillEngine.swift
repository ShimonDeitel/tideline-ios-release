import Foundation
import Combine

/// Drives a full daily drill: three escalating 20-second rounds (tables, mixed ops, word problems).
/// Each round runs on a per-round countdown; answering advances to the next problem instantly.
/// When all three rounds finish (or time out), `onComplete` fires exactly once with the tally.
@MainActor
final class DrillEngine: ObservableObject {
    static let roundSeconds = 20.0

    enum Phase: Equatable { case idle, playing, betweenRounds, done }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var roundIndex = 0            // 0...2
    @Published private(set) var problemIndex = 0
    @Published private(set) var current: Problem?
    @Published private(set) var timeRemaining = roundSeconds
    @Published private(set) var roundCorrect = 0
    @Published private(set) var lastWasCorrect: Bool?     // for instant feedback flash
    @Published private(set) var isComplete = false

    var hapticsEnabled = true
    var onComplete: ((DrillTally, Tier) -> Void)?

    private(set) var tier: Tier = .easy
    private var rounds: [[Problem]] = []
    private var tally = DrillTally()
    private var timer: AnyCancellable?
    private var problemStart = Date()

    var roundKind: RoundKind { RoundKind.drillOrder[min(roundIndex, 2)] }
    var totalRounds: Int { RoundKind.drillOrder.count }

    // MARK: Lifecycle

    /// Begin the day's drill. `rounds` is the three pre-generated rounds for today.
    func start(rounds: [[Problem]], tier: Tier) {
        cancelTimer()
        self.rounds = rounds
        self.tier = tier
        tally = DrillTally()
        roundIndex = 0
        isComplete = false
        beginRound()
    }

    private func beginRound() {
        problemIndex = 0
        roundCorrect = 0
        lastWasCorrect = nil
        timeRemaining = Self.roundSeconds
        phase = .playing
        loadCurrent()
        startTimer()
        if hapticsEnabled { Haptics.soft() }
    }

    private func loadCurrent() {
        let round = rounds.indices.contains(roundIndex) ? rounds[roundIndex] : []
        current = round.indices.contains(problemIndex) ? round[problemIndex] : nil
        problemStart = Date()
        // If a round somehow has no problems, end it immediately.
        if current == nil { finishRound() }
    }

    // MARK: Answering

    /// Record the player's choice for the current problem and advance.
    func answer(_ choice: Int) {
        guard phase == .playing, let problem = current else { return }
        let correct = problem.isCorrect(choice)
        let elapsed = min(Date().timeIntervalSince(problemStart), Self.roundSeconds)
        tally.record(op: problem.op, correct: correct, elapsed: elapsed)
        if correct { roundCorrect += 1 }
        lastWasCorrect = correct
        if hapticsEnabled { correct ? Haptics.success() : Haptics.tap() }
        advanceProblem()
    }

    private func advanceProblem() {
        let round = rounds.indices.contains(roundIndex) ? rounds[roundIndex] : []
        if problemIndex + 1 < round.count {
            problemIndex += 1
            loadCurrent()
        } else {
            // Ran out of problems before time — keep generating? No: round ends, move on.
            finishRound()
        }
    }

    private func finishRound() {
        cancelTimer()
        if roundIndex + 1 < totalRounds {
            roundIndex += 1
            phase = .betweenRounds
        } else {
            complete()
        }
    }

    /// Called from the UI to advance from the between-rounds card into the next round.
    func continueToNextRound() {
        guard phase == .betweenRounds else { return }
        beginRound()
    }

    private func complete() {
        cancelTimer()
        phase = .done
        isComplete = true
        current = nil
        onComplete?(tally, tier)
        if hapticsEnabled { Haptics.success() }
    }

    /// Player abandons the drill early. Never fires onComplete.
    func cancel() {
        cancelTimer()
        phase = .idle
        isComplete = false
        current = nil
    }

    // MARK: Timer

    private func startTimer() {
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick(0.1) }
    }

    private func tick(_ dt: Double) {
        guard phase == .playing else { return }
        timeRemaining = max(0, timeRemaining - dt)
        if timeRemaining <= 0 { finishRound() }
    }

    private func cancelTimer() { timer?.cancel(); timer = nil }
}
