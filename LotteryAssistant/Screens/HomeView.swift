import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var isPresentingTicketEntry: Bool
    @Query(sort: \LotteryDraw.drawDate, order: .reverse) private var draws: [LotteryDraw]
    @Query(sort: \LotteryTicket.purchaseDate, order: .reverse) private var tickets: [LotteryTicket]

    private var pendingTickets: [LotteryTicket] {
        tickets.filter { $0.status == .pendingDraw }
    }

    private var wonTickets: [LotteryTicket] {
        tickets.filter { $0.status == .won || $0.status == .redeemed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                header
                metrics
                latestDrawSection
                recentTicketsSection
                disclaimer
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("彩票助手")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingTicketEntry = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加彩票")
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("记录每一份期待")
                .font(.largeTitle.bold())
            Text("开奖信息、票据核验和个人账本都在这里。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
    }

    private var metrics: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            MetricCard(title: "待开奖", value: "\(pendingTickets.count)", symbol: "clock.fill", tint: .orange)
            MetricCard(title: "已中奖", value: "\(wonTickets.count)", symbol: "star.fill", tint: AppTheme.Color.positive)
            MetricCard(title: "累计投入", value: "¥\(tickets.reduce(0) { $0 + Int($1.purchaseCost) })", symbol: "chart.line.uptrend.xyaxis", tint: AppTheme.Color.primary)
        }
    }

    private var latestDrawSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("最新开奖")
                    .font(.title3.bold())
                Spacer()
                NavigationLink("查看全部") {
                    DrawListView()
                }
                .font(.subheadline.weight(.semibold))
            }

            if draws.isEmpty {
                EmptyState(symbol: "calendar.badge.exclamationmark", title: "暂时没有开奖信息", message: "请稍后刷新开奖数据。")
            } else {
                ForEach(Array(draws.prefix(2))) { draw in
                    NavigationLink {
                        DrawDetailView(draw: draw)
                    } label: {
                        DrawSummaryCard(draw: draw)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentTicketsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("最近保存")
                    .font(.title3.bold())
                Spacer()
                NavigationLink("我的彩票") {
                    TicketListView(isPresentingTicketEntry: $isPresentingTicketEntry)
                }
                .font(.subheadline.weight(.semibold))
            }

            if let ticket = tickets.first {
                NavigationLink {
                    TicketDetailView(ticket: ticket)
                } label: {
                    TicketSummaryCard(ticket: ticket)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    isPresentingTicketEntry = true
                } label: {
                    Label("录入第一张彩票", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var disclaimer: some View {
        Label("开奖结果为随机事件；历史数据和随机选号仅供娱乐，不会提高中奖概率。", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(AppTheme.Color.secondaryText)
            .padding(AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous))
    }
}

struct DrawSummaryCard: View {
    let draw: LotteryDraw

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                LotteryKindBadge(kind: draw.kind)
                Spacer()
                Text(draw.drawDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            NumberRow(frontNumbers: draw.frontNumbers, backNumbers: draw.backNumbers)
            HStack {
                Text("第 \(draw.issueNumber) 期")
                Spacer()
                Text("奖池 ¥\(draw.poolAmount / 100_000_000, format: .number.precision(.fractionLength(2))) 亿")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .appCard()
    }
}

struct TicketSummaryCard: View {
    let ticket: LotteryTicket

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                LotteryKindBadge(kind: ticket.kind)
                Spacer()
                Text(ticket.status.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ticket.status.tint)
            }
            NumberRow(frontNumbers: ticket.frontNumbers, backNumbers: ticket.backNumbers)
            Text("第 \(ticket.issueNumber) 期 · \(ticket.multiplier) 倍")
                .font(.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .appCard()
    }
}
