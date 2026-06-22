import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store, derives streak/accuracy/speed stats, and records each
/// completed daily drill. Stats are always derived from results — never stored as truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var totalDrills = 0
    @Published private(set) var bestAccuracy = 0.0      // 0...1
    @Published private(set) var lifetimeAccuracy = 0.0  // 0...1
    @Published private(set) var fastestSeconds = 0.0    // best seconds-per-problem (lower better)
    @Published private(set) var didDrillToday = false

    init(container: ModelContainer) {
        self.container = container
        #if DEBUG
        seedIfRequested()
        #endif
        refresh()
    }

    // MARK: Container (local-only persistence — no CloudKit, no special entitlements)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([DailyResult.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Results

    func recordDrill(_ tally: DrillTally, tier: Tier) {
        let ctx = container.mainContext
        ctx.insert(tally.makeResult(tier: tier))
        try? ctx.save()
        refresh()
    }

    func recentResults(limit: Int = 60) -> [DailyResult] {
        var d = FetchDescriptor<DailyResult>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        d.fetchLimit = limit
        return (try? container.mainContext.fetch(d)) ?? []
    }

    /// Aggregated per-operation accuracy across all results (for the weak-spot view).
    func weakSpots() -> [OpAccuracy] {
        let all = (try? container.mainContext.fetch(FetchDescriptor<DailyResult>())) ?? []
        let add = all.reduce(into: (0, 0)) { $0.0 += $1.addCorrect; $0.1 += $1.addTotal }
        let sub = all.reduce(into: (0, 0)) { $0.0 += $1.subCorrect; $0.1 += $1.subTotal }
        let mul = all.reduce(into: (0, 0)) { $0.0 += $1.mulCorrect; $0.1 += $1.mulTotal }
        let div = all.reduce(into: (0, 0)) { $0.0 += $1.divCorrect; $0.1 += $1.divTotal }
        return [
            OpAccuracy(op: .add, correct: add.0, total: add.1),
            OpAccuracy(op: .subtract, correct: sub.0, total: sub.1),
            OpAccuracy(op: .multiply, correct: mul.0, total: mul.1),
            OpAccuracy(op: .divide, correct: div.0, total: div.1)
        ].filter { $0.total > 0 }
    }

    // MARK: Stats

    func refresh() {
        let all = (try? container.mainContext.fetch(FetchDescriptor<DailyResult>())) ?? []
        totalDrills = all.count
        bestAccuracy = all.map(\.accuracy).max() ?? 0
        let totalCorrect = all.reduce(0) { $0 + $1.correct }
        let totalAnswered = all.reduce(0) { $0 + $1.total }
        lifetimeAccuracy = totalAnswered > 0 ? Double(totalCorrect) / Double(totalAnswered) : 0
        fastestSeconds = all.filter { $0.total > 0 }.map(\.secondsPerProblem).min() ?? 0

        let cal = Calendar.current
        let days = Set(all.map { cal.startOfDay(for: $0.date) })
        didDrillToday = days.contains(cal.startOfDay(for: .now))
        currentStreak = Self.currentStreak(days: days, cal: cal)
        longestStreak = Self.longestStreak(days: days, cal: cal)
    }

    nonisolated static func currentStreak(days: Set<Date>, cal: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var day = cal.startOfDay(for: .now)
        // If today isn't logged yet, the streak still stands as of yesterday.
        if !days.contains(day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day), days.contains(yesterday)
            else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    nonisolated static func longestStreak(days: Set<Date>, cal: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var best = 1, run = 1
        for i in 1..<sorted.count {
            if let prev = cal.date(byAdding: .day, value: 1, to: sorted[i - 1]), prev == sorted[i] {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    // MARK: Tier availability

    /// Tiers the player can select: free tiers always, Pro tiers only when unlocked.
    func availableTiers(isPro: Bool) -> [Tier] {
        isPro ? Tier.all : Tier.free
    }

    // MARK: Account / data management

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: DailyResult.self)
        try? ctx.save()
        refresh()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let n = env["QUICKMATH_SEED"].flatMap(Int.init), n > 0 else { return }
        let ctx = container.mainContext
        if ((try? ctx.fetch(FetchDescriptor<DailyResult>()))?.isEmpty ?? true) {
            let cal = Calendar.current
            for offset in 0..<n {
                if let day = cal.date(byAdding: .day, value: -offset, to: .now) {
                    let correct = 9 + (offset % 5)
                    ctx.insert(DailyResult(
                        date: day, tierRaw: Tier.all[offset % Tier.all.count].rawValue,
                        correct: correct, total: 15, seconds: Double(40 + offset % 20),
                        addCorrect: 3, addTotal: 4, subCorrect: 2, subTotal: 4,
                        mulCorrect: 3, mulTotal: 4, divCorrect: 1, divTotal: 3))
                }
            }
            try? ctx.save()
        }
    }
    #endif
}
