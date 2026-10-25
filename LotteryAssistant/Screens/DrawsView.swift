import SwiftUI
import SwiftData

struct DrawListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(LotteryRuleSettings.isDoubleColorBallFortunePrizeEnabled)
    private var isDoubleColorBallFortunePrizeEnabled = false
    @State private var selectedKind: LotteryKind = .doubleColorBall
    @State private var pageCount = 1
    @State private var lastRequestedPage: Int?
    @State private var isSynchronizing = false
    @State private var syncMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("彩种", selection: $selectedKind) {
                ForEach(LotteryKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedKind) {
                pageCount = 1
                lastRequestedPage = nil
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(.bar)

            DrawPageList(kind: selectedKind, pageCount: pageCount) { page in
                guard page == pageCount - 1, lastRequestedPage != page else { return }
                lastRequestedPage = page
                pageCount += 1
            }
        }
        .navigationTitle("开奖中心")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await synchronize() }
                } label: {
                    if isSynchronizing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isSynchronizing)
                .accessibilityLabel("刷新开奖数据")
            }
        }
        .alert("开奖数据同步", isPresented: Binding(
            get: { syncMessage != nil },
            set: { if !$0 { syncMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(syncMessage ?? "")
        }
    }

    @MainActor
    private func synchronize() async {
        isSynchronizing = true
        defer { isSynchronizing = false }
        do {
            let provider = FallbackLotteryDataProvider(
                primary: OfficialLotteryDataProvider(),
                fallback: YangLotteryDataProvider()
            )
            let count = try await DrawSyncService(provider: provider).synchronize(
                context: modelContext,
                isDoubleColorBallFortunePrizeEnabled: isDoubleColorBallFortunePrizeEnabled
            )
            syncMessage = count == 0 ? "没有发现新的开奖期次。" : "已同步 \(count) 期最新开奖数据。"
        } catch {
            syncMessage = error.localizedDescription
        }
    }
}

private struct DrawPageList: View {
    let kind: LotteryKind
    let pageCount: Int
    let onLoadMore: (Int) -> Void

    var body: some View {
        List {
            ForEach(0..<pageCount, id: \.self) { page in
                DrawPageRows(
                    kind: kind,
                    page: page,
                    isLastPage: page == pageCount - 1,
                    onLoadMore: onLoadMore
                )
            }
        }
        .listStyle(.plain)
    }
}

private struct DrawPageRows: View {
    @Query private var draws: [LotteryDraw]
    let page: Int
    let isLastPage: Bool
    let onLoadMore: (Int) -> Void

    init(kind: LotteryKind, page: Int, isLastPage: Bool, onLoadMore: @escaping (Int) -> Void) {
        let rawValue = kind.rawValue
        var descriptor = FetchDescriptor<LotteryDraw>(
            predicate: #Predicate { $0.lotteryRawValue == rawValue },
            sortBy: [SortDescriptor(\.drawDate, order: .reverse)]
        )
        descriptor.fetchLimit = 25
        descriptor.fetchOffset = page * 25
        _draws = Query(descriptor, animation: .default)
        self.page = page
        self.isLastPage = isLastPage
        self.onLoadMore = onLoadMore
    }

    var body: some View {
        if page == 0 && draws.isEmpty {
            EmptyState(symbol: "calendar.badge.exclamationmark", title: "暂无开奖记录", message: "该彩种的开奖数据尚未同步。")
        } else {
            ForEach(draws) { draw in
                NavigationLink {
                    DrawDetailView(draw: draw)
                } label: {
                    DrawListRow(draw: draw)
                }
                .onAppear {
                    guard isLastPage,
                          draw.recordID == draws.last?.recordID,
                          draws.count == 25 else {
                        return
                    }
                    onLoadMore(page)
                }
            }
        }
    }
}

struct DrawListRow: View {
    let draw: LotteryDraw

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Text("第 \(draw.issueNumber) 期")
                    .font(.headline)
                Spacer()
                Text(draw.drawDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            NumberRow(frontNumbers: draw.frontNumbers, backNumbers: draw.backNumbers)
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }
}

struct DrawDetailView: View {
    let draw: LotteryDraw

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    LotteryKindBadge(kind: draw.kind)
                    Text("第 \(draw.issueNumber) 期")
                        .font(.title2.bold())
                    Text(draw.drawDate.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .appCard()

                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("开奖号码")
                        .font(.headline)
                    NumberRow(frontNumbers: draw.frontNumbers, backNumbers: draw.backNumbers)
                    Divider()
                    LabeledContent("奖池金额", value: String(format: "¥%.0f", draw.poolAmount))
                    LabeledContent("数据来源", value: draw.sourceLabel)
                }
                .appCard()

                Label("奖金、奖级与兑奖期限以官方当期规则为准。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("开奖详情")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
