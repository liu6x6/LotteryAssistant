import SwiftUI
import SwiftData

struct InsightsView: View {
    @Binding var isPresentingTicketEntry: Bool
    @Query(sort: \LotteryDraw.drawDate, order: .reverse) private var draws: [LotteryDraw]
    @Query(sort: \LotteryTicket.purchaseDate, order: .reverse) private var tickets: [LotteryTicket]
    @State private var kind: LotteryKind = .doubleColorBall
    @State private var generatedFront: [Int] = []
    @State private var generatedBack: [Int] = []

    private var relevantDraws: [LotteryDraw] {
        draws.filter { $0.kind == kind }
    }

    private var totalCost: Double {
        tickets.reduce(0) { $0 + $1.purchaseCost }
    }

    private var totalIncome: Double {
        tickets.reduce(0) { $0 + $1.estimatedPrize }
    }

    private var netIncome: Double {
        totalIncome - totalCost
    }

    private var hasUnconfirmedPrize: Bool {
        tickets.contains {
            ($0.status == .won || $0.status == .redeemed) && $0.estimatedPrize == 0
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Picker("彩种", selection: $kind) {
                    ForEach(LotteryKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                randomPicker
                statistics
                disclaimer
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("选号与统计")
        .background(Color(uiColor: .systemGroupedBackground))
        .onChange(of: kind) {
            generatedFront = []
            generatedBack = []
        }
    }

    private var randomPicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("随机选号")
                        .font(.title3.bold())
                    Text("随机生成一注 \(kind.displayName) 号码")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                Spacer()
                Image(systemName: "die.face.5.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Color.accent)
            }

            if generatedFront.isEmpty {
                Text("点击下方按钮生成号码")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                NumberRow(frontNumbers: generatedFront, backNumbers: generatedBack)
                    .frame(maxWidth: .infinity)
            }

            Button {
                generateNumbers()
            } label: {
                Label(generatedFront.isEmpty ? "随机生成一注" : "换一注号码", systemImage: "shuffle")
            }
            .buttonStyle(PrimaryButtonStyle())

            if !generatedFront.isEmpty {
                Button {
                    isPresentingTicketEntry = true
                } label: {
                    Text("去录入这张彩票")
                        .frame(maxWidth: .infinity)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .appCard()
    }

    private var statistics: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("个人账本")
                .font(.title3.bold())
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm), count: 2),
                spacing: AppTheme.Spacing.sm
            ) {
                MetricCard(title: "已保存", value: "\(tickets.count) 张", symbol: "ticket.fill", tint: AppTheme.Color.primary)
                MetricCard(title: "累计投入", value: String(format: "¥%.0f", totalCost), symbol: "creditcard.fill", tint: AppTheme.Color.accent)
                MetricCard(title: "中奖收入", value: String(format: "¥%.0f", totalIncome), symbol: "yensign.circle.fill", tint: AppTheme.Color.positive)
                MetricCard(
                    title: "净收益",
                    value: String(format: "%@¥%.0f", netIncome < 0 ? "-" : "", abs(netIncome)),
                    symbol: netIncome >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    tint: netIncome >= 0 ? AppTheme.Color.positive : AppTheme.Color.error
                )
            }
            if hasUnconfirmedPrize {
                Label("奖金待确认的彩票暂未计入中奖收入。", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Divider()
            Text("历史开奖样本")
                .font(.headline)
            Text("当前已载入 \(relevantDraws.count) 期 \(kind.displayName) 开奖记录。接入经授权的数据源后，此处将展示号码频率、区间分布与遗漏统计。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .appCard()
    }

    private var disclaimer: some View {
        Label("历史统计和随机选号仅供娱乐；每一组合法号码的理论中奖概率相同。", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(AppTheme.Color.secondaryText)
    }

    private func generateNumbers() {
        generatedFront = Array(kind.frontRange).shuffled().prefix(kind.frontCount).sorted()
        generatedBack = Array(kind.backRange).shuffled().prefix(kind.backCount).sorted()
    }
}
