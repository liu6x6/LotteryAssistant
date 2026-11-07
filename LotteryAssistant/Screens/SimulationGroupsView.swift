import SwiftData
import SwiftUI

struct SimulationGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SimulationMode.activeGroupIDKey) private var activeGroupID = ""
    @Query(sort: \SimulationGroup.createdAt, order: .reverse) private var groups: [SimulationGroup]
    @Query(sort: \LotteryTicket.purchaseDate, order: .reverse) private var tickets: [LotteryTicket]
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""
    @State private var errorMessage: String?

    private var activeGroup: SimulationGroup? {
        guard let id = UUID(uuidString: activeGroupID) else { return nil }
        return groups.first { $0.id == id }
    }

    var body: some View {
        List {
            if let activeGroup {
                Section {
                    LabeledContent("正在模拟", value: activeGroup.name)
                    Button("退出模拟模式", role: .destructive) {
                        activeGroupID = ""
                    }
                } header: {
                    Text("当前模拟模式")
                } footer: {
                    Text("手动录入、随机选号和统计推荐号码会自动加入“\(activeGroup.name)”。")
                }
            }

            Section {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "还没有模拟组",
                        systemImage: "wand.and.stars",
                        description: Text("创建模拟组后即可开始记录虚拟彩票。")
                    )
                } else {
                    ForEach(groups) { group in
                        NavigationLink {
                            SimulationGroupDetailView(group: group)
                        } label: {
                            SimulationGroupRow(group: group, tickets: ticketsForGroup(group))
                        }
                    }
                    .onDelete(perform: deleteGroups)
                }
            } header: {
                Text("模拟组")
            }
        }
        .navigationTitle("模拟买彩票")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newGroupName = ""
                    isCreatingGroup = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("创建模拟组")
            }
        }
        .alert("创建模拟组", isPresented: $isCreatingGroup) {
            TextField("模拟组名称", text: $newGroupName)
            Button("创建") { createGroup() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("例如：双色球长期模拟")
        }
        .alert("操作未完成", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func ticketsForGroup(_ group: SimulationGroup) -> [LotteryTicket] {
        tickets.filter { $0.simulationGroup?.id == group.id }
    }

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "请输入模拟组名称。"
            return
        }

        let group = SimulationGroup(name: name)
        modelContext.insert(group)
        do {
            try modelContext.save()
            activeGroupID = group.id.uuidString
        } catch {
            modelContext.rollback()
            errorMessage = "无法创建模拟组：\(error.localizedDescription)"
        }
    }

    private func deleteGroups(at offsets: IndexSet) {
        let deletedGroups = offsets.map { groups[$0] }
        for index in offsets {
            let group = groups[index]
            ticketsForGroup(group).forEach(modelContext.delete)
            modelContext.delete(group)
        }

        do {
            try modelContext.save()
            if deletedGroups.contains(where: { $0.id.uuidString == activeGroupID }) {
                activeGroupID = ""
            }
        } catch {
            modelContext.rollback()
            errorMessage = "无法删除模拟组：\(error.localizedDescription)"
        }
    }
}

private struct SimulationGroupRow: View {
    let group: SimulationGroup
    let tickets: [LotteryTicket]

    private var totalCost: Double {
        tickets.reduce(0) { $0 + $1.purchaseCost }
    }

    private var totalIncome: Double {
        tickets.reduce(0) { $0 + $1.estimatedPrize }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(group.name)
                .font(.headline)
            Text("\(tickets.count) 张 · 投入 ¥\(totalCost, format: .number.precision(.fractionLength(0))) · 净收益 ¥\((totalIncome - totalCost), format: .number.precision(.fractionLength(0)))")
                .font(.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
    }
}

private struct SimulationGroupDetailView: View {
    @AppStorage(SimulationMode.activeGroupIDKey) private var activeGroupID = ""
    @Query(sort: \LotteryTicket.purchaseDate, order: .reverse) private var allTickets: [LotteryTicket]
    let group: SimulationGroup

    private var tickets: [LotteryTicket] {
        allTickets.filter { $0.simulationGroup?.id == group.id }
    }

    private var totalCost: Double {
        tickets.reduce(0) { $0 + $1.purchaseCost }
    }

    private var totalIncome: Double {
        tickets.reduce(0) { $0 + $1.estimatedPrize }
    }

    private var pendingCount: Int {
        tickets.filter { $0.status == .pendingDraw }.count
    }

    var body: some View {
        List {
            Section {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm), count: 2),
                    spacing: AppTheme.Spacing.sm
                ) {
                    MetricCard(title: "模拟票", value: "\(tickets.count) 张", symbol: "ticket.fill", tint: AppTheme.Color.primary)
                    MetricCard(title: "待开奖", value: "\(pendingCount) 张", symbol: "clock.fill", tint: .orange)
                    MetricCard(title: "模拟投入", value: String(format: "¥%.0f", totalCost), symbol: "creditcard.fill", tint: AppTheme.Color.accent)
                    MetricCard(
                        title: "模拟净收益",
                        value: String(format: "%@¥%.0f", totalIncome - totalCost < 0 ? "-" : "", abs(totalIncome - totalCost)),
                        symbol: totalIncome >= totalCost ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        tint: totalIncome >= totalCost ? AppTheme.Color.positive : AppTheme.Color.error
                    )
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            }

            Section {
                NavigationLink {
                    TicketEntryView()
                } label: {
                    Label("录入模拟彩票", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text("随机选号和统计推荐号码也会自动加入当前模拟组。")
            }

            Section("模拟票据") {
                if tickets.isEmpty {
                    Text("暂无模拟票据")
                        .foregroundStyle(AppTheme.Color.secondaryText)
                } else {
                    ForEach(tickets) { ticket in
                        NavigationLink {
                            TicketDetailView(ticket: ticket)
                        } label: {
                            TicketSummaryCard(ticket: ticket)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .onAppear {
            activeGroupID = group.id.uuidString
        }
    }
}
