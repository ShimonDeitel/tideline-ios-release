import SwiftUI

/// A self-contained card rendered to an image for sharing a drill result (Pro feature).
/// No system colors — uses explicit values so the off-screen render looks right.
struct ResultShareCard: View {
    let result: DailyResult
    let streak: Int

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "function")
                    .font(.system(size: 26, weight: .semibold))
                Text("QuickMath")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.qmAccent)

            Text(percentString(result.accuracy))
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("\(result.correct)/\(result.total) correct · \(result.tier.label)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 20) {
                stat(value: String(format: "%.1fs", result.secondsPerProblem), label: "per problem")
                stat(value: "\(streak)", label: "day streak")
            }
            .padding(.top, 4)

            Text("60-second daily math drills")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 6)
        }
        .padding(40)
        .frame(width: 440, height: 440)
        .background(Color.black)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label).font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
