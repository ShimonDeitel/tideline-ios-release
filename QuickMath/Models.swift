import Foundation
import SwiftData

/// One completed daily drill. All properties have defaults and there are no unique constraints,
/// so the schema is CloudKit-mirroring compatible (SwiftData + CloudKit private DB).
@Model
final class DailyResult {
    var id: UUID = UUID()
    var date: Date = Date.now
    var tierRaw: String = "easy"

    /// Totals across all three rounds.
    var correct: Int = 0
    var total: Int = 0
    /// Total time spent answering, in seconds (drill is 3 × 20s capped).
    var seconds: Double = 0

    /// Per-operation correct / attempted, for the weak-spot view.
    var addCorrect: Int = 0
    var addTotal: Int = 0
    var subCorrect: Int = 0
    var subTotal: Int = 0
    var mulCorrect: Int = 0
    var mulTotal: Int = 0
    var divCorrect: Int = 0
    var divTotal: Int = 0

    init(id: UUID = UUID(), date: Date = .now, tierRaw: String = "easy",
         correct: Int = 0, total: Int = 0, seconds: Double = 0,
         addCorrect: Int = 0, addTotal: Int = 0,
         subCorrect: Int = 0, subTotal: Int = 0,
         mulCorrect: Int = 0, mulTotal: Int = 0,
         divCorrect: Int = 0, divTotal: Int = 0) {
        self.id = id
        self.date = date
        self.tierRaw = tierRaw
        self.correct = correct
        self.total = total
        self.seconds = seconds
        self.addCorrect = addCorrect; self.addTotal = addTotal
        self.subCorrect = subCorrect; self.subTotal = subTotal
        self.mulCorrect = mulCorrect; self.mulTotal = mulTotal
        self.divCorrect = divCorrect; self.divTotal = divTotal
    }

    var tier: Tier { Tier(rawValue: tierRaw) ?? .easy }

    /// Accuracy as a 0...1 fraction (0 when nothing was attempted).
    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }

    /// Average answer speed in seconds per problem.
    var secondsPerProblem: Double { total > 0 ? seconds / Double(total) : 0 }
}

/// Per-operation accuracy used by the weak-spot view (pure value type).
struct OpAccuracy: Identifiable {
    let op: Op
    let correct: Int
    let total: Int
    var id: String { op.rawValue }
    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
    var label: String {
        switch op {
        case .add: return "Addition"
        case .subtract: return "Subtraction"
        case .multiply: return "Multiplication"
        case .divide: return "Division"
        }
    }
}

/// Mutable accumulator a drill fills in as the player answers, then converts to a `DailyResult`.
struct DrillTally {
    var correct = 0
    var total = 0
    var seconds: Double = 0
    var perOp: [Op: (correct: Int, total: Int)] = [:]

    mutating func record(op: Op, correct isCorrect: Bool, elapsed: Double) {
        total += 1
        seconds += elapsed
        if isCorrect { correct += 1 }
        var entry = perOp[op] ?? (0, 0)
        entry.total += 1
        if isCorrect { entry.correct += 1 }
        perOp[op] = entry
    }

    func makeResult(tier: Tier, date: Date = .now) -> DailyResult {
        let a = perOp[.add] ?? (0, 0)
        let s = perOp[.subtract] ?? (0, 0)
        let m = perOp[.multiply] ?? (0, 0)
        let d = perOp[.divide] ?? (0, 0)
        return DailyResult(
            date: date, tierRaw: tier.rawValue,
            correct: correct, total: total, seconds: seconds,
            addCorrect: a.correct, addTotal: a.total,
            subCorrect: s.correct, subTotal: s.total,
            mulCorrect: m.correct, mulTotal: m.total,
            divCorrect: d.correct, divTotal: d.total)
    }
}
