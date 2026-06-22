import SwiftUI

struct HomeView: View {
    var forceScreen: String?

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @AppStorage("quickmath.tier") private var tierRaw = Tier.easy.rawValue

    @State private var showDrill = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var lastResult: DailyResult?

    private let generator = ProblemGenerator()

    private var selectedTier: Tier {
        let t = Tier(rawValue: tierRaw) ?? .easy
        return (t.isPro && !store.isPro) ? .easy : t
    }

    private var allTiers: [Tier] { Tier.all }

    var body: some View {
        ZStack {
            QMBackground()
            ScrollView {
                VStack(spacing: 0) {
                    header
                    hero.padding(.top, 18)
                    statRow.padding(.top, 22)
                    tierPicker.padding(.top, 22)
                    startButton.padding(.top, 24)
                    todayNote.padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $showDrill, onDismiss: {
            appModel.refresh()
        }) {
            DrillView(tier: selectedTier,
                      rounds: generator.dailyDrill(date: .now, tier: selectedTier)) { result in
                lastResult = result
            }
        }
        .sheet(isPresented: $showStats) { StatsView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            appModel.refresh()
            applyForceScreen()
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(appModel.currentStreak > 0 ? Color.qmAccent : .secondary)
                Text(appModel.currentStreak > 0 ? "\(appModel.currentStreak)-day streak" : "Start your streak")
                    .font(.subheadline.weight(.semibold))
            }
            .qmPill()

            Spacer()

            Button { Haptics.tap(); showStats = true } label: {
                Image(systemName: "chart.bar.fill").font(.title3)
            }
            .tint(.primary)
            .padding(.trailing, 14)
            .accessibilityIdentifier("open-stats")
            .accessibilityLabel("Statistics")

            Button { Haptics.tap(); showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3)
            }
            .tint(.primary)
            .accessibilityIdentifier("open-settings")
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.qmAccent.opacity(0.10)).frame(width: 150, height: 150)
                Image(systemName: "function")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.qmAccent)
            }
            VStack(spacing: 4) {
                Text("Today's Drill").font(.title2.weight(.bold))
                Text("Three 20-second rounds: tables, mixed ops, word problems.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(appModel.currentStreak)", label: "Day streak")
            MetricTile(value: appModel.totalDrills > 0 ? percentString(appModel.bestAccuracy) : "—",
                       label: "Best accuracy")
            MetricTile(value: "\(appModel.totalDrills)", label: "Drills")
        }
    }

    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Difficulty").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allTiers) { t in
                        let locked = t.isPro && !store.isPro
                        TierChip(tier: t, selected: t.id == selectedTier.id, locked: locked) {
                            Haptics.tap()
                            if locked { showPaywall = true } else { tierRaw = t.id }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var startButton: some View {
        Button {
            Haptics.soft(); showDrill = true
        } label: {
            Text(appModel.didDrillToday ? "Drill Again" : "Start Drill")
                .frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .prominentButton()
        .accessibilityIdentifier("start-drill")
    }

    @ViewBuilder
    private var todayNote: some View {
        if appModel.didDrillToday {
            Label("You've kept your streak today. Nice.", systemImage: "checkmark.seal.fill")
                .font(.footnote).foregroundStyle(.secondary)
        } else {
            Text("Same drill for everyone today — beat your best.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func applyForceScreen() {
        guard let s = forceScreen else { return }
        switch s {
        case "stats": showStats = true
        case "settings": showSettings = true
        case "paywall": showPaywall = true
        case "drill": showDrill = true
        default: break
        }
    }
}
