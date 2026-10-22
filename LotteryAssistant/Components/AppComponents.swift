import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}

struct LotteryKindBadge: View {
    let kind: LotteryKind

    var body: some View {
        Text(kind.displayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(kind.tint)
            .padding(.horizontal, AppTheme.Spacing.xs)
            .padding(.vertical, AppTheme.Spacing.xxs)
            .background(kind.tint.opacity(0.12), in: Capsule())
    }
}
