//
//  LotteryAssistantApp.swift
//  LotteryAssistant
//
//  Created by xiaolong on 2026/10/22.
//

import SwiftUI
import SwiftData

@main
struct LotteryAssistantApp: App {
    private let modelContainer: ModelContainer
    @AppStorage(AppAppearance.storageKey) var appearanceRawValue = AppAppearance.system.rawValue

    init() {
        do {
            modelContainer = try ModelContainer(for: LotteryDraw.self, LotteryTicket.self, SimulationGroup.self)
            try AppDataMaintenance.removeLegacyDemoDraws(context: modelContainer.mainContext)
        } catch {
            fatalError("无法初始化本地数据存储：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppAppearance(rawValue: appearanceRawValue)?.colorScheme)
        }
        .modelContainer(modelContainer)
    }
}
