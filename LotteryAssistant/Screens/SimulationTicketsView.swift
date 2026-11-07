import SwiftData
import SwiftUI

struct SimulationTicketsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SimulationGroup.createdAt, order: .reverse) private var groups: [SimulationGroup]
    @Query private var tickets: [LotteryTicket]
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "还没有模拟组",
                    systemImage: "wand.and.stars",
                    description: Text("创建模拟组后即可录入和统计模拟彩票。")
                )
            } else {
                ForEach(groups) { group in
                    NavigationLink {
                        SimulationGroupTicketsView(group: group)
                    } label: {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text(group.name)
                                .font(.headline)
                            Text("\(tickets.filter { $0.simulationGroup?.id == group.id }.count) 张模拟彩票")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                    }
                }
                .onDelete(perform: deleteGroups)
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
            Button("创建") {
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    errorMessage = "请输入模拟组名称。"
                    return
                }
                modelContext.insert(SimulationGroup(name: name))
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    errorMessage = "无法创建模拟组：\(error.localizedDescription)"
                }
            }
            Button("取消", role: .cancel) {}
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

    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            let group = groups[index]
            tickets.filter { $0.simulationGroup?.id == group.id }.forEach(modelContext.delete)
            modelContext.delete(group)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "无法删除模拟组：\(error.localizedDescription)"
        }
    }
}

private struct SimulationGroupTicketsView: View {
    let group: SimulationGroup
    @State private var isPresentingTicketEntry = false

    var body: some View {
        TicketListView(
            isPresentingTicketEntry: $isPresentingTicketEntry,
            isSimulation: true,
            simulationGroup: group
        )
        .sheet(isPresented: $isPresentingTicketEntry) {
            NavigationStack {
                TicketEntryView(isSimulation: true, simulationGroup: group)
            }
        }
    }
}
