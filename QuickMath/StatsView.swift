import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 12) {
                        MetricTile(value: "\(appModel.currentStreak)", label: "Day streak")
                        MetricTile(value: "\(appModel.longestStreak)", label: "Best streak")
                        MetricTile(value: appModel.totalDrills > 0 ? percentString(appModel.lifetimeAccuracy) : "—",
                                   label: "Avg accuracy")
                        MetricTile(value: "\(appModel.totalDrills)", label: "Drills")
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if appModel.fastestSeconds > 0 {
                        MetricTile(value: String(format: "%.1fs", appModel.fastestSeconds),
                                   label: "Fastest pace (per problem)")
                            .padding(.horizontal)
                    }

                    proContent.padding(.top, 6)
                }
            }
            .navigationTitle("Your progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .tint(Color.qmAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    @ViewBuilder
    private var proContent: some View {
        if store.isPro {
            accuracyChart
            weakSpotsSection
            historySection
        } else {
            lockedCard
        }
    }

    // MARK: Pro — accuracy chart

    private var accuracyChart: some View {
        let results = appModel.recentResults(limit: 14).reversed().map { $0 }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Accuracy over time").font(.headline).padding(.horizontal)
            if results.isEmpty {
                emptyNote("Your accuracy trend will appear here.")
            } else {
                Chart(results) { r in
                    LineMark(
                        x: .value("Day", r.date),
                        y: .value("Accuracy", r.accuracy * 100)
                    )
                    .foregroundStyle(Color.qmAccent)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Day", r.date),
                        y: .value("Accuracy", r.accuracy * 100)
                    )
                    .foregroundStyle(Color.qmAccent)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
                .padding(14)
                .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
            }
        }
    }

    // MARK: Pro — weak spots

    private var weakSpotsSection: some View {
        let spots = appModel.weakSpots().sorted { $0.accuracy < $1.accuracy }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Weak-spot focus").font(.headline).padding(.horizontal)
            if spots.isEmpty {
                emptyNote("Play a few drills to see which operations to work on.")
            } else {
                VStack(spacing: 14) {
                    ForEach(spots) { s in
                        VStack(spacing: 6) {
                            HStack {
                                Text(s.label).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(percentString(s.accuracy))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            AccuracyBar(fraction: s.accuracy,
                                        tint: s.accuracy < 0.6 ? .qmWrong : .qmAccent)
                        }
                    }
                }
                .padding(16)
                .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
            }
        }
    }

    // MARK: Pro — history list

    private var historySection: some View {
        let results = appModel.recentResults()
        return VStack(alignment: .leading, spacing: 10) {
            Text("History").font(.headline).padding(.horizontal)
            if results.isEmpty {
                emptyNote("Your drills will appear here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(results) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(r.tier.label) · \(percentString(r.accuracy))")
                                    .font(.subheadline.weight(.medium))
                                Text(r.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(r.correct)/\(r.total)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12).padding(.horizontal, 16)
                        if r.id != results.last?.id { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: Free — locked upsell

    private var lockedCard: some View {
        Button { Haptics.tap(); showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill").foregroundStyle(Color.qmAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock your full history")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("Accuracy charts, weak-spot focus and every past drill with QuickMath Pro.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
            .padding(.horizontal)
    }
}
