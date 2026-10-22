import Foundation
import SwiftData

enum AppDataMaintenance {
    static func removeLegacyDemoDraws(context: ModelContext) throws {
        let descriptor = FetchDescriptor<LotteryDraw>(
            predicate: #Predicate { $0.sourceLabel == "内置演示数据" }
        )
        try context.fetch(descriptor).forEach(context.delete)
        try context.save()
    }
}
