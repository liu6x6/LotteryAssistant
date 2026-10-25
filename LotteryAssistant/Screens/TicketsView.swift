import SwiftUI
import SwiftData

struct TicketListView: View {
    @Binding var isPresentingTicketEntry: Bool
    @State private var selectedStatus: TicketStatus?
    @State private var pageCount = 1
    @State private var lastRequestedPage: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    TicketStatusFilter(title: "全部", isSelected: selectedStatus == nil) {
                        selectedStatus = nil
                        pageCount = 1
                        lastRequestedPage = nil
                    }
                    ForEach(TicketStatus.allCases, id: \.rawValue) { status in
                        TicketStatusFilter(title: status.displayName, isSelected: selectedStatus == status) {
                            selectedStatus = status
                            pageCount = 1
                            lastRequestedPage = nil
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
            }
            .background(.bar)

            TicketPageList(status: selectedStatus, pageCount: pageCount) { page in
                guard page == pageCount - 1, lastRequestedPage != page else { return }
                lastRequestedPage = page
                pageCount += 1
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
    }
}

private struct TicketPageList: View {
    let status: TicketStatus?
    let pageCount: Int
    let onLoadMore: (Int) -> Void

    var body: some View {
        List {
            ForEach(0..<pageCount, id: \.self) { page in
                TicketPageRows(
                    status: status,
                    page: page,
                    isLastPage: page == pageCount - 1,
                    onLoadMore: onLoadMore
                )
            }
        }
        .listStyle(.plain)
    }
}

private struct TicketPageRows: View {
    @Query private var tickets: [LotteryTicket]
    let page: Int
    let isLastPage: Bool
    let onLoadMore: (Int) -> Void

    init(status: TicketStatus?, page: Int, isLastPage: Bool, onLoadMore: @escaping (Int) -> Void) {
        var descriptor: FetchDescriptor<LotteryTicket>
        if let status {
            let rawValue = status.rawValue
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.statusRawValue == rawValue },
                sortBy: [SortDescriptor(\.purchaseDate, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.purchaseDate, order: .reverse)])
        }
        descriptor.fetchLimit = 25
        descriptor.fetchOffset = page * 25
        _tickets = Query(descriptor, animation: .default)
        self.page = page
        self.isLastPage = isLastPage
        self.onLoadMore = onLoadMore
    }

    var body: some View {
        if page == 0 && tickets.isEmpty {
            EmptyState(symbol: "ticket", title: "还没有保存的彩票", message: "录入彩票后，开奖时即可自动核验。")
        } else {
            ForEach(tickets) { ticket in
                NavigationLink {
                    TicketDetailView(ticket: ticket)
                } label: {
                    TicketListRow(ticket: ticket)
                }
                .onAppear {
                    guard isLastPage,
                          ticket.id == tickets.last?.id,
                          tickets.count == 25 else {
                        return
                    }
                    onLoadMore(page)
                }
            }
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
            if ticket.status == .won || ticket.status == .redeemed {
                HStack {
                    Label(ticket.prizeLevel ?? "已中奖", systemImage: "trophy.fill")
                    Spacer()
                    Text(ticket.estimatedPrize > 0 ? String(format: "预计奖金 ¥%.0f", ticket.estimatedPrize) : "奖金待确认")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Color.positive)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }
}

struct TicketDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LotteryDraw.drawDate, order: .reverse) private var draws: [LotteryDraw]
    let ticket: LotteryTicket
    @State private var persistenceError: String?
    @State private var isEditing = false
    @State private var isConfirmingDeletion = false

    private var matchingDraw: LotteryDraw? {
        let issue = LotteryIssue.normalize(ticket.issueNumber, for: ticket.kind)
        return draws.first {
            $0.kind == ticket.kind
                && LotteryIssue.normalize($0.issueNumber, for: ticket.kind) == issue
        }
    }

    private var matchedFrontNumbers: Set<Int> {
        guard let matchingDraw else { return [] }
        return Set(ticket.frontNumbers).intersection(matchingDraw.frontNumbers)
    }

    private var matchedBackNumbers: Set<Int> {
        guard let matchingDraw else { return [] }
        return Set(ticket.backNumbers).intersection(matchingDraw.backNumbers)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                ticketCard
                resultCard
                drawCard
                prizeTableButton
                notice
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("票据详情")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditing = true
                    } label: {
                        Label("修改彩票", systemImage: "pencil")
                    }

                    if ticket.status == .won {
                        Button {
                        ticket.statusRawValue = TicketStatus.redeemed.rawValue
                        do {
                            try modelContext.save()
                        } catch {
                            ticket.statusRawValue = TicketStatus.won.rawValue
                            persistenceError = "无法更新兑奖状态：\(error.localizedDescription)"
                        }
                        } label: {
                            Label("标记已兑奖", systemImage: "checkmark.seal")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        isConfirmingDeletion = true
                    } label: {
                        Label("删除彩票", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                TicketEntryView(ticket: ticket)
            }
        }
        .confirmationDialog(
            "确定删除这张彩票吗？",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("删除彩票", role: .destructive) {
                deleteTicket()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
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
            NumberRow(
                frontNumbers: ticket.frontNumbers,
                backNumbers: ticket.backNumbers,
                matchedFrontNumbers: matchedFrontNumbers,
                matchedBackNumbers: matchedBackNumbers
            )
            if matchingDraw != nil, !matchedFrontNumbers.isEmpty || !matchedBackNumbers.isEmpty {
                Label("红色外圈表示该号码已命中", systemImage: "circle.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.error)
            }
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
                if ticket.status == .won || ticket.status == .redeemed {
                    winningSummary
                } else {
                    Label("本期未中奖", systemImage: "xmark.circle")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }

                Divider()

                LabeledContent("前区命中", value: "\(ticket.matchedFrontCount) 个")
                LabeledContent("后区命中", value: "\(ticket.matchedBackCount) 个")
                if let checkedAt = ticket.checkedAt {
                    LabeledContent("核验时间", value: checkedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
    }

    @ViewBuilder
    private var drawCard: some View {
        if let matchingDraw {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack {
                    Text("本期开奖号码")
                        .font(.headline)
                    Spacer()
                    Text(matchingDraw.drawDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                NumberRow(
                    frontNumbers: matchingDraw.frontNumbers,
                    backNumbers: matchingDraw.backNumbers
                )
                Text("第 \(matchingDraw.issueNumber) 期")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        } else {
            EmptyState(
                symbol: "calendar.badge.exclamationmark",
                title: "暂无本期开奖号码",
                message: "请先在开奖中心刷新对应期次的数据。"
            )
            .appCard()
        }
    }

    @ViewBuilder
    private var prizeTableButton: some View {
        switch ticket.kind {
        case .doubleColorBall:
            NavigationLink {
                DoubleColorBallPrizeTableView(draw: matchingDraw)
            } label: {
                Label("查看双色球奖金对照表", systemImage: "tablecells")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        case .superLotto:
            NavigationLink {
                SuperLottoPrizeTableView(draw: matchingDraw)
            } label: {
                Label("查看大乐透奖金对照表", systemImage: "tablecells")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var winningSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label("恭喜中奖", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.Color.positive)

            Text(ticket.prizeLevel ?? "已中奖")
                .font(.title2.bold())

            if ticket.estimatedPrize > 0 {
                Text(String(format: "¥%.0f", ticket.estimatedPrize))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Color.positive)
                    .monospacedDigit()
                Text("预计奖金收入（已包含 \(ticket.multiplier) 倍投注\(ticket.isAdditional ? "及追加奖金" : "")）")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            } else {
                Text("奖金待官方确认")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.Color.accent)
                Text("当前开奖数据未包含该奖级金额，请刷新开奖数据或查看当期官方公告。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.positive.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
    }

    private var notice: some View {
        Label("核验结果仅供参考，请以官方兑奖结果和当期规则为准。", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(AppTheme.Color.secondaryText)
    }

    private func deleteTicket() {
        modelContext.delete(ticket)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            persistenceError = "无法删除彩票：\(error.localizedDescription)"
        }
    }
}
