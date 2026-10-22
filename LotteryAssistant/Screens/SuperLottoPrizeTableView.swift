import SwiftUI

struct SuperLottoPrizeTableView: View {
    let draw: LotteryDraw?

    private let rows: [SuperLottoPrizeRow] = [
        .init(level: "一等奖", fallbackAmount: "浮动", conditions: [.init(frontMatches: 5, backMatches: 2)]),
        .init(level: "二等奖", fallbackAmount: "浮动", conditions: [.init(frontMatches: 5, backMatches: 1)]),
        .init(
            level: "三等奖",
            fallbackAmount: "¥5,000\n加成 ¥6,666",
            conditions: [
                .init(frontMatches: 5, backMatches: 0),
                .init(frontMatches: 4, backMatches: 2)
            ]
        ),
        .init(level: "四等奖", fallbackAmount: "¥300\n加成 ¥380", conditions: [.init(frontMatches: 4, backMatches: 1)]),
        .init(
            level: "五等奖",
            fallbackAmount: "¥150\n加成 ¥200",
            conditions: [
                .init(frontMatches: 4, backMatches: 0),
                .init(frontMatches: 3, backMatches: 2)
            ]
        ),
        .init(
            level: "六等奖",
            fallbackAmount: "¥15\n加成 ¥18",
            conditions: [
                .init(frontMatches: 3, backMatches: 1),
                .init(frontMatches: 2, backMatches: 2)
            ]
        ),
        .init(
            level: "七等奖",
            fallbackAmount: "¥5\n加成 ¥7",
            conditions: [
                .init(frontMatches: 3, backMatches: 0),
                .init(frontMatches: 2, backMatches: 1),
                .init(frontMatches: 1, backMatches: 2),
                .init(frontMatches: 0, backMatches: 2)
            ]
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

                Label("红色圆圈表示命中的前区号码，蓝色圆圈表示命中的后区号码，灰色圆圈表示未命中。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)

                Text("一、二等奖为浮动奖金，追加投注可获得对应追加奖金。部分期次固定奖存在加成，表内优先显示当期官方实际单注奖金。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)

                Text("奖金、追加比例和加成规则请以当期中国体育彩票官方公告为准。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("大乐透中奖规则")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        HStack(spacing: 0) {
            tableCell("奖级", width: 78)
            tableDivider
            tableCell("单注奖金", width: 108)
            tableDivider
            Text("中奖条件")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
        }
        .background(Color(uiColor: .systemGray4))
    }

    private func prizeRow(_ row: SuperLottoPrizeRow) -> some View {
        HStack(spacing: 0) {
            Text(row.level)
                .font(.body.weight(.semibold))
                .frame(width: 78)

            tableDivider

            amountView(for: row)
                .frame(width: 108)

            tableDivider

            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(row.conditions) { condition in
                    SuperLottoConditionView(condition: condition)
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

    private func amountView(for row: SuperLottoPrizeRow) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            if let amount = draw?.prizeAmount(for: row.level), amount > 0 {
                Text("本期")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                Text("¥\(amount, format: .number.precision(.fractionLength(0)))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.positive)

                if let additional = draw?.prizeAmount(for: "\(row.level)(追加)"), additional > 0 {
                    Text("追加 +¥\(additional, format: .number.precision(.fractionLength(0)))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Color.primary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text(row.fallbackAmount)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
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

private struct SuperLottoPrizeRow: Identifiable {
    let id = UUID()
    let level: String
    let fallbackAmount: String
    let conditions: [SuperLottoCondition]
}

private struct SuperLottoCondition: Identifiable {
    let id = UUID()
    let frontMatches: Int
    let backMatches: Int
}

private struct SuperLottoConditionView: View {
    let condition: SuperLottoCondition

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < condition.frontMatches ? AppTheme.Color.redBall : Color(uiColor: .systemGray4))
                    .frame(width: 15, height: 15)
            }
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index < condition.backMatches ? AppTheme.Color.blueBall : Color(uiColor: .systemGray4))
                    .frame(width: 15, height: 15)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(condition.frontMatches) 个前区号码，\(condition.backMatches) 个后区号码")
    }
}
