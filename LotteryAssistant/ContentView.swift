import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isPresentingTicketEntry = false
    @State private var ticketEntryPrefill: TicketEntryPrefill?

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(isPresentingTicketEntry: $isPresentingTicketEntry)
            }
            .tabItem { Label("首页", systemImage: "house.fill") }

            NavigationStack {
                TicketListView(isPresentingTicketEntry: $isPresentingTicketEntry)
            }
            .tabItem { Label("彩票", systemImage: "ticket.fill") }

            NavigationStack {
                InsightsView(
                    isPresentingTicketEntry: $isPresentingTicketEntry,
                    ticketEntryPrefill: $ticketEntryPrefill
                )
            }
            .tabItem { Label("选号", systemImage: "shuffle") }

            NavigationStack {
                StatisticsView(
                    isPresentingTicketEntry: $isPresentingTicketEntry,
                    ticketEntryPrefill: $ticketEntryPrefill
                )
            }
            .tabItem { Label("统计", systemImage: "chart.bar.xaxis") }

            NavigationStack {
                SimulationTicketsView()
            }
            .tabItem { Label("模拟", systemImage: "wand.and.stars") }
        }
        .tint(AppTheme.Color.primary)
        .sheet(isPresented: $isPresentingTicketEntry) {
            NavigationStack {
                TicketEntryView(prefill: ticketEntryPrefill)
            }
        }
        .onChange(of: isPresentingTicketEntry) {
            if !isPresentingTicketEntry {
                ticketEntryPrefill = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LotteryDraw.self, LotteryTicket.self, SimulationGroup.self], inMemory: true)
}
