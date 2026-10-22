import SwiftUI

struct DoubleColorBallPrizeTableView: View {
    let draw: LotteryDraw?

    private let rows: [DoubleColorBallPrizeRow] = [
        .init(level: "一等奖", amount: .floating, conditions: [.init(frontMatches: 6, backMatches: true)]),
        .init(level: "二等奖", amount: .floating, conditions: [.init(frontMatches: 6, backMatches: false)]),
        .init(level: "三等奖", amount: .fixed(3_000), conditions: [.init(frontMatches: 5, backMatches: true)]),
        .init(
            level: "四等奖",
            amount: .fixed(200),
            conditions: [
                .init(frontMatches: 5, backMatches: false),
                .init(frontMatches: 4, backMatches: true)
            ]
        ),
        .init(
            level: "五等奖",
            amount: .fixed(10),
            conditions: [
                .init(frontMatches: 4, backMatches: false),
                .init(frontMatches: 3, backMatches: true)
            ]
        ),
        .init(
            level: "六等奖",
            amount: .fixed(5),
            conditions: [
                .init(frontMatches: 2, backMatches: true),
                .init(frontMatches: 1, backMatches: true),
                .init(frontMatches: 0, backMatches: true)
            ]
        ),
        .init(
            level: "福运奖",
            subtitle: "执行特别规定期间",
            amount: .fixed(5),
            conditions: [.init(frontMatches: 3, backMatches: false)]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("奖金对照表")
                    .font(.largeTitle.bold())

                VStack(spacing: 0) {
                    header
                    ForEach(rows) { row in
                        prizeRow(row)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .stroke(Color.secondary.opacity(0.2))
                }

                Label("红色圆圈表示命中的红球，蓝色圆圈表示命中的蓝球，灰色圆圈表示未命中。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)

                Text("一等奖、二等奖为浮动奖金；福运奖仅在官方特别规定执行期间适用。所有奖金和活动规则请以当期官方公告为准。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("双色球中奖规则")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        HStack(spacing: 0) {
            tableCell("奖级", width: 82)
            tableDivider
            tableCell("单注奖金", width: 100)
            tableDivider
            Text("中奖条件")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
        }
        .background(Color(uiColor: .systemGray4))
    }

    private func prizeRow(_ row: DoubleColorBallPrizeRow) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                Text(row.level)
                    .font(.body.weight(.semibold))
                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 82)

            tableDivider

            amountView(for: row)
                .frame(width: 100)

            tableDivider

            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(row.conditions) { condition in
                    DoubleColorBallConditionView(condition: condition)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.Spacing.xs)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(minHeight: 74)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private func amountView(for row: DoubleColorBallPrizeRow) -> some View {
        switch row.amount {
        case .floating:
            VStack(spacing: AppTheme.Spacing.xxs) {
                Text("浮动")
                    .font(.body.weight(.semibold))
                if let amount = draw?.prizeAmount(for: row.level), amount > 0 {
                    Text("本期 ¥\(amount, format: .number.precision(.fractionLength(0)))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Color.positive)
                        .multilineTextAlignment(.center)
                }
            }
        case .fixed(let amount):
            Text("¥\(amount, format: .number)")
                .font(.body.weight(.semibold))
        }
    }

    private func tableCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.headline)
            .frame(width: width)
            .padding(.vertical, AppTheme.Spacing.md)
    }

    private var tableDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.8))
            .frame(width: 1)
    }
}

private struct DoubleColorBallPrizeRow: Identifiable {
    let id = UUID()
    let level: String
    var subtitle: String?
    let amount: DoubleColorBallPrizeAmount
    let conditions: [DoubleColorBallCondition]
}

private enum DoubleColorBallPrizeAmount {
    case floating
    case fixed(Int)
}

private struct DoubleColorBallCondition: Identifiable {
    let id = UUID()
    let frontMatches: Int
    let backMatches: Bool
}

private struct DoubleColorBallConditionView: View {
    let condition: DoubleColorBallCondition

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < condition.frontMatches ? AppTheme.Color.redBall : Color(uiColor: .systemGray4))
                    .frame(width: 15, height: 15)
            }
            Circle()
                .fill(condition.backMatches ? AppTheme.Color.blueBall : Color(uiColor: .systemGray4))
                .frame(width: 15, height: 15)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(condition.frontMatches) 个红球，\(condition.backMatches ? "命中蓝球" : "未命中蓝球")")
    }
}
