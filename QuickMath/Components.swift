import SwiftUI

/// A selectable difficulty-tier chip; shows a small lock when the tier is Pro and the user isn't.
struct TierChip: View {
    let tier: Tier
    let selected: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Text(tier.label).font(.subheadline.weight(.semibold))
                    if locked {
                        Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                    }
                }
                Text(tier.blurb).font(.caption2)
                    .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(minWidth: 96)
            .background(
                selected ? Color.qmAccent : Color.qmCard,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tier-\(tier.id)")
    }
}

/// A small labelled metric tile used on Home and Stats.
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.qmAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// One large tappable answer choice used in the drill.
struct ChoiceButton: View {
    let value: Int
    let state: State
    let action: () -> Void

    enum State { case normal, correct, wrong }

    private var bg: Color {
        switch state {
        case .normal: return .qmCard
        case .correct: return .qmCorrect
        case .wrong: return .qmWrong
        }
    }
    private var fg: Color { state == .normal ? .primary : .white }

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(fg)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("choice-\(value)")
    }
}

/// A slim horizontal accuracy bar (0...1) used for weak-spots and history.
struct AccuracyBar: View {
    let fraction: Double      // 0...1
    var tint: Color = .qmAccent
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.qmField)
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 8)
    }
}

/// Wraps UIActivityViewController so we can share a rendered result card image.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

func percentString(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}
