import SwiftUI
import SwiftData

struct DrawListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(LotteryRuleSettings.isDoubleColorBallFortunePrizeEnabled)
    private var isDoubleColorBallFortunePrizeEnabled = false
    @State private var selectedKind: LotteryKind = .doubleColorBall
    @State private var isSynchronizing = false
    @State private var syncMessage: String?
    @Query(sort: \LotteryDraw.drawDate, order: .reverse) private var draws: [LotteryDraw]

    private var filteredDraws: [LotteryDraw] {
        draws.filter { $0.kind == selectedKind }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("彩种", selection: $selectedKind) {
                ForEach(LotteryKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(.bar)

            Group {
                if filteredDraws.isEmpty {
                    EmptyState(symbol: "calendar.badge.exclamationmark", title: "暂无开奖记录", message: "该彩种的开奖数据尚未同步。")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredDraws) { draw in
                        NavigationLink {
                            DrawDetailView(draw: draw)
                        } label: {
                            DrawListRow(draw: draw)
                        }
                    }
                    .listStyle(.plain)
                }
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
