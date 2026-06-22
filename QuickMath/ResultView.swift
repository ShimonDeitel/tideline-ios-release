import SwiftUI

/// Shown after a drill: the score, accuracy, speed, the streak, and (Pro) a share button.
struct ResultView: View {
    let result: DailyResult

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showShare = false
    @State private var showPaywall = false
    @State private var shareImage: UIImage?

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            QMBackground()
            ScrollView {
                VStack(spacing: 22) {
                    headline.padding(.top, 30)
                    scoreGrid
                    streakLine
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: Pieces

    private var grade: (String, String) {
        let a = result.accuracy
        switch a {
        case 0.9...:    return ("Sharp!", "star.fill")
        case 0.7..<0.9: return ("Solid work", "checkmark.seal.fill")
        case 0.5..<0.7: return ("Keep going", "arrow.up.right")
        default:        return ("Warmed up", "figure.run")
        }
    }

    private var headline: some View {
        VStack(spacing: 10) {
            Image(systemName: grade.1)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.qmAccent)
            Text(grade.0).font(.largeTitle.weight(.heavy))
            Text("\(result.correct) of \(result.total) correct")
                .font(.title3).foregroundStyle(.secondary)
        }
    }

    private var scoreGrid: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            MetricTile(value: percentString(result.accuracy), label: "Accuracy")
            MetricTile(value: String(format: "%.1fs", result.secondsPerProblem), label: "Per problem")
            MetricTile(value: result.tier.label, label: "Difficulty")
            MetricTile(value: "\(result.total)", label: "Problems")
        }
    }

    private var streakLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill").foregroundStyle(Color.qmAccent)
            Text(appModel.currentStreak > 0
                 ? "\(appModel.currentStreak)-day streak — keep it alive tomorrow"
                 : "Come back tomorrow to build a streak")
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button { Haptics.soft(); dismiss() } label: {
                Text("Done").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .accessibilityIdentifier("result-done")

            Button {
                Haptics.tap()
                if store.isPro { renderAndShare() } else { showPaywall = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: store.isPro ? "square.and.arrow.up" : "lock.fill")
                    Text(store.isPro ? "Share result" : "Share result (Pro)")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .softButton()
            .accessibilityIdentifier("result-share")
        }
    }

    @MainActor
    private func renderAndShare() {
        let card = ResultShareCard(result: result, streak: appModel.currentStreak)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        if let img = renderer.uiImage {
            shareImage = img
            showShare = true
        }
    }
}
