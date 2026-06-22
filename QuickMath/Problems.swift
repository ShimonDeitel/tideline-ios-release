import Foundation

// MARK: - Difficulty tiers

/// A difficulty tier scopes the operand ranges and operations a round may draw from.
/// `easy` and `medium` are free; `hard` and `expert` are Pro bonuses.
enum Tier: String, CaseIterable, Identifiable, Codable {
    case easy, medium, hard, expert

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var isPro: Bool { self == .hard || self == .expert }

    var blurb: String {
        switch self {
        case .easy:   return "Small numbers, gentle warm-up"
        case .medium: return "Bigger numbers, all four operations"
        case .hard:   return "Two-digit work and tougher division"
        case .expert: return "Large operands, no mercy"
        }
    }

    static let free: [Tier] = [.easy, .medium]
    static let pro: [Tier]  = [.hard, .expert]
    static let all: [Tier]  = [.easy, .medium, .hard, .expert]
}

// MARK: - Round kinds (the three escalating round types)

/// The three kinds of round, played in this order each drill.
enum RoundKind: String, CaseIterable, Identifiable, Codable {
    case tables      // multiplication / times-tables
    case mixed       // mixed +, -, x, ÷
    case word        // word problems

    var id: String { rawValue }
    var title: String {
        switch self {
        case .tables: return "Tables"
        case .mixed:  return "Mixed ops"
        case .word:   return "Word problems"
        }
    }
    var systemImage: String {
        switch self {
        case .tables: return "multiply"
        case .mixed:  return "plusminus"
        case .word:   return "text.book.closed"
        }
    }
    /// The ordered three rounds of a drill.
    static let drillOrder: [RoundKind] = [.tables, .mixed, .word]
}

// MARK: - Operations

enum Op: String, Codable {
    case add, subtract, multiply, divide

    var symbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        }
    }
}

// MARK: - A single problem

/// One generated problem. `answer` is the correct integer; `choices` are four shuffled options.
struct Problem: Identifiable, Equatable {
    let id: Int
    let prompt: String          // "7 × 8" or a word-problem sentence
    let answer: Int
    let choices: [Int]
    let op: Op
    let kind: RoundKind

    func isCorrect(_ choice: Int) -> Bool { choice == answer }
}

// MARK: - Word-problem template (decoded from the bundled JSON)

struct WordTemplate: Codable {
    let tier: String
    let text: String
    let op: Op
    let aRange: [Int]
    let bRange: [Int]
}

private struct WordTemplateFile: Codable {
    let templates: [WordTemplate]
}

// MARK: - Deterministic RNG (so a given day yields the same drill on every device)

/// SplitMix64 — a tiny, well-distributed, fully deterministic PRNG.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - The generator (pure, deterministic, no I/O at call time)

/// Builds a full daily drill (three rounds) procedurally from a date seed and a tier.
/// Pure and deterministic: same (date, tier, count) always yields the same problems, so the
/// "drill of the day" is identical everywhere with no server.
struct ProblemGenerator {
    /// Word-problem templates, loaded once from the bundle (falls back to a built-in set).
    let wordTemplates: [WordTemplate]

    init(wordTemplates: [WordTemplate]? = nil) {
        self.wordTemplates = wordTemplates ?? ProblemGenerator.loadBundledTemplates()
    }

    /// A stable integer seed for a calendar day in a given time zone.
    static func daySeed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = UInt64(c.year ?? 2026)
        let m = UInt64(c.month ?? 1)
        let d = UInt64(c.day ?? 1)
        return y &* 10_000 &+ m &* 100 &+ d
    }

    /// Produce the three ordered rounds for the day. Each round has `perRound` problems.
    func dailyDrill(date: Date, tier: Tier, perRound: Int = 5,
                    calendar: Calendar = .current) -> [[Problem]] {
        let base = ProblemGenerator.daySeed(for: date, calendar: calendar)
        return RoundKind.drillOrder.enumerated().map { idx, kind in
            // Distinct seed per round so the three rounds differ but stay deterministic.
            var rng = SeededRNG(seed: base &* 31 &+ UInt64(idx + 1) &+ UInt64(tier.hashValue & 0xFFFF))
            return round(kind: kind, tier: tier, count: perRound, rng: &rng)
        }
    }

    /// Generate a single round of `count` problems of one kind at a tier.
    func round(kind: RoundKind, tier: Tier, count: Int, rng: inout SeededRNG) -> [Problem] {
        (0..<count).map { i in
            switch kind {
            case .tables: return tablesProblem(id: i, tier: tier, rng: &rng)
            case .mixed:  return mixedProblem(id: i, tier: tier, rng: &rng)
            case .word:   return wordProblem(id: i, tier: tier, rng: &rng)
            }
        }
    }

    // MARK: Round builders

    private func tablesProblem(id: Int, tier: Tier, rng: inout SeededRNG) -> Problem {
        let r = tableRange(tier)
        let a = Int.random(in: r.0, using: &rng)
        let b = Int.random(in: r.1, using: &rng)
        let answer = a * b
        return Problem(id: id, prompt: "\(a) × \(b)", answer: answer,
                       choices: choices(for: answer, op: .multiply, rng: &rng),
                       op: .multiply, kind: .tables)
    }

    private func mixedProblem(id: Int, tier: Tier, rng: inout SeededRNG) -> Problem {
        let ops: [Op] = [.add, .subtract, .multiply, .divide]
        let op = ops[Int.random(in: 0...3, using: &rng)]
        let (a, b, answer, prompt) = operands(for: op, tier: tier, rng: &rng)
        _ = (a, b)
        return Problem(id: id, prompt: prompt, answer: answer,
                       choices: choices(for: answer, op: op, rng: &rng),
                       op: op, kind: .mixed)
    }

    private func wordProblem(id: Int, tier: Tier, rng: inout SeededRNG) -> Problem {
        let pool = wordTemplates.filter { $0.tier == wordTier(for: tier) }
        let templates = pool.isEmpty ? wordTemplates : pool
        guard !templates.isEmpty else {
            // Defensive fallback if no templates loaded at all.
            return tablesProblem(id: id, tier: tier, rng: &rng)
        }
        let t = templates[Int.random(in: 0..<templates.count, using: &rng)]
        let a = Int.random(in: clamp(t.aRange), using: &rng)
        var b = Int.random(in: clamp(t.bRange), using: &rng)
        var ans: Int
        switch t.op {
        case .add:      ans = a + b
        case .subtract: ans = max(a, b) - min(a, b)
        case .multiply: ans = a * b
        case .divide:
            // Make division clean: answer = a, then the dividend is a*b.
            b = max(2, b)
            ans = a
        }
        let shownA = (t.op == .divide) ? a * b : a
        let text = t.text
            .replacingOccurrences(of: "{a}", with: "\(shownA)")
            .replacingOccurrences(of: "{b}", with: "\(b)")
        return Problem(id: id, prompt: text, answer: ans,
                       choices: choices(for: ans, op: t.op, rng: &rng),
                       op: t.op, kind: .word)
    }

    // MARK: Operand math

    private func operands(for op: Op, tier: Tier, rng: inout SeededRNG) -> (Int, Int, Int, String) {
        switch op {
        case .add:
            let r = addRange(tier)
            let a = Int.random(in: r, using: &rng)
            let b = Int.random(in: r, using: &rng)
            return (a, b, a + b, "\(a) + \(b)")
        case .subtract:
            let r = addRange(tier)
            let x = Int.random(in: r, using: &rng)
            let y = Int.random(in: r, using: &rng)
            let a = max(x, y), b = min(x, y)
            return (a, b, a - b, "\(a) − \(b)")
        case .multiply:
            let r = tableRange(tier)
            let a = Int.random(in: r.0, using: &rng)
            let b = Int.random(in: r.1, using: &rng)
            return (a, b, a * b, "\(a) × \(b)")
        case .divide:
            // Clean division: build dividend from quotient * divisor.
            let r = tableRange(tier)
            let quotient = Int.random(in: r.0, using: &rng)
            let divisor = max(2, Int.random(in: r.1, using: &rng))
            let dividend = quotient * divisor
            return (dividend, divisor, quotient, "\(dividend) ÷ \(divisor)")
        }
    }

    // MARK: Tier ranges

    private func tableRange(_ tier: Tier) -> (ClosedRange<Int>, ClosedRange<Int>) {
        switch tier {
        case .easy:   return (2...9, 2...9)
        case .medium: return (2...12, 2...12)
        case .hard:   return (6...15, 6...15)
        case .expert: return (9...19, 9...19)
        }
    }

    private func addRange(_ tier: Tier) -> ClosedRange<Int> {
        switch tier {
        case .easy:   return 2...20
        case .medium: return 10...60
        case .hard:   return 25...150
        case .expert: return 80...500
        }
    }

    private func wordTier(for tier: Tier) -> String {
        switch tier {
        case .easy:   return "easy"
        case .medium: return "medium"
        case .hard, .expert: return "hard"
        }
    }

    // MARK: Distractor choices

    /// Four shuffled options including the answer; distractors are plausible near-misses.
    private func choices(for answer: Int, op: Op, rng: inout SeededRNG) -> [Int] {
        var set = Set<Int>([answer])
        let spread = max(2, abs(answer) / 8)
        var guard0 = 0
        while set.count < 4 && guard0 < 40 {
            guard0 += 1
            let delta = Int.random(in: 1...max(2, spread + 3), using: &rng)
            let sign = Bool.random(using: &rng) ? 1 : -1
            let candidate = answer + sign * delta
            if candidate >= 0 && candidate != answer { set.insert(candidate) }
        }
        // Top up if we couldn't find enough (very small answers).
        var n = answer + 1
        while set.count < 4 { if n != answer && n >= 0 { set.insert(n) }; n += 1 }
        return Array(set).shuffled(using: &rng)
    }

    private func clamp(_ pair: [Int]) -> ClosedRange<Int> {
        guard pair.count == 2 else { return 1...9 }
        let lo = min(pair[0], pair[1]), hi = max(pair[0], pair[1])
        return lo...max(lo, hi)
    }

    // MARK: Bundle loading

    static func loadBundledTemplates() -> [WordTemplate] {
        guard let url = Bundle.main.url(forResource: "wordproblems", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(WordTemplateFile.self, from: data) else {
            return fallbackTemplates
        }
        return file.templates.isEmpty ? fallbackTemplates : file.templates
    }

    /// Built-in templates so the generator always works even if the resource is missing.
    static let fallbackTemplates: [WordTemplate] = [
        WordTemplate(tier: "easy", text: "You have {a} apples and pick {b} more. How many now?",
                     op: .add, aRange: [3, 20], bRange: [2, 15]),
        WordTemplate(tier: "easy", text: "A box holds {a} pencils. You buy {b} boxes. How many pencils?",
                     op: .multiply, aRange: [2, 9], bRange: [2, 6]),
        WordTemplate(tier: "medium", text: "Tickets cost {a} each. You buy {b}. Total cost?",
                     op: .multiply, aRange: [5, 15], bRange: [2, 8]),
        WordTemplate(tier: "hard", text: "A bakery makes {a} loaves a day. How many in {b} days?",
                     op: .multiply, aRange: [12, 25], bRange: [4, 12])
    ]
}
