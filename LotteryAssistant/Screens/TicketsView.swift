import SwiftUI
import SwiftData

struct TicketListView: View {
    @Binding var isPresentingTicketEntry: Bool
    @Query(sort: \LotteryTicket.purchaseDate, order: .reverse) private var tickets: [LotteryTicket]
    @State private var selectedStatus: TicketStatus?

    private var visibleTickets: [LotteryTicket] {
        guard let selectedStatus else { return tickets }
        return tickets.filter { $0.status == selectedStatus }
    }

    var body: some View {
        Group {
            if visibleTickets.isEmpty {
                EmptyState(symbol: "ticket", title: "还没有保存的彩票", message: "录入彩票后，开奖时即可自动核验。")
            } else {
                List(visibleTickets) { ticket in
                    NavigationLink {
                        TicketDetailView(ticket: ticket)
                    } label: {
                        TicketListRow(ticket: ticket)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("我的彩票")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingTicketEntry = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("录入彩票")
            }
        }
        .safeAreaInset(edge: .top) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    TicketStatusFilter(title: "全部", isSelected: selectedStatus == nil) {
                        selectedStatus = nil
                    }
                    ForEach(TicketStatus.allCases, id: \.rawValue) { status in
                        TicketStatusFilter(title: status.displayName, isSelected: selectedStatus == status) {
                            selectedStatus = status
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
            }
            .background(.bar)
        }
    }
}

private struct TicketStatusFilter: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.Color.secondaryText)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(isSelected ? AppTheme.Color.primary : AppTheme.Color.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct TicketListRow: View {
    let ticket: LotteryTicket

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                LotteryKindBadge(kind: ticket.kind)
                Text("第 \(ticket.issueNumber) 期")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(ticket.status.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ticket.status.tint)
            }
            NumberRow(frontNumbers: ticket.frontNumbers, backNumbers: ticket.backNumbers)
            Text("购买于 \(ticket.purchaseDate.formatted(date: .abbreviated, time: .omitted)) · \(ticket.multiplier) 倍")
                .font(.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }
}

struct TicketDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let ticket: LotteryTicket
    @State private var persistenceError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                ticketCard
                resultCard
                notice
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("票据详情")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            if ticket.status == .won {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("标记已兑奖") {
                        ticket.statusRawValue = TicketStatus.redeemed.rawValue
                        do {
                            try modelContext.save()
                        } catch {
                            ticket.statusRawValue = TicketStatus.won.rawValue
                            persistenceError = "无法更新兑奖状态：\(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        .alert("操作未完成", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "")
        }
    }

    private var ticketCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                LotteryKindBadge(kind: ticket.kind)
                Spacer()
                Text(ticket.status.displayName)
                    .font(.headline)
                    .foregroundStyle(ticket.status.tint)
            }
            Text("第 \(ticket.issueNumber) 期")
                .font(.title3.bold())
            NumberRow(frontNumbers: ticket.frontNumbers, backNumbers: ticket.backNumbers)
            Divider()
            LabeledContent("投注倍数", value: "\(ticket.multiplier) 倍")
            if ticket.kind == .superLotto {
                LabeledContent("追加投注", value: ticket.isAdditional ? "是" : "否")
            }
            LabeledContent("投注金额", value: String(format: "¥%.0f", ticket.purchaseCost))
        }
        .appCard()
    }

    @ViewBuilder
    private var resultCard: some View {
        if ticket.status == .pendingDraw {
            EmptyState(symbol: "clock.badge.questionmark", title: "等待开奖", message: "开奖数据同步后会自动核验这张彩票。")
                .appCard()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(ticket.status == .won || ticket.status == .redeemed ? "核验结果" : "本期未中奖")
                    .font(.headline)
                HStack(spacing: AppTheme.Spacing.lg) {
                    VStack(alignment: .leading) {
                        Text("\(ticket.matchedFrontCount)")
                            .font(.title.bold())
                        Text("前区命中")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Color.secondaryText)
                    }
                    VStack(alignment: .leading) {
                        Text("\(ticket.matchedBackCount)")
                            .font(.title.bold())
                        Text("后区命中")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Color.secondaryText)
                    }
                    if let prizeLevel = ticket.prizeLevel {
                        VStack(alignment: .leading) {
                            Text(prizeLevel)
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.Color.positive)
                            Text("中奖等级")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
    }

    private var notice: some View {
        Label("核验结果仅供参考，请以官方兑奖结果和当期规则为准。", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(AppTheme.Color.secondaryText)
    }
}
