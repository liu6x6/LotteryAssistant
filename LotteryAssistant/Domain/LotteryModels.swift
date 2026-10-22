import Foundation
import SwiftData
import SwiftUI

enum LotteryKind: String, Codable, CaseIterable, Identifiable {
    case doubleColorBall
    case superLotto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .doubleColorBall: "双色球"
        case .superLotto: "超级大乐透"
        }
    }

    var frontRange: ClosedRange<Int> {
        switch self {
        case .doubleColorBall: 1...33
        case .superLotto: 1...35
        }
    }

    var backRange: ClosedRange<Int> {
        switch self {
        case .doubleColorBall: 1...16
        case .superLotto: 1...12
        }
    }

    var frontCount: Int {
        switch self {
        case .doubleColorBall: 6
        case .superLotto: 5
        }
    }

    var backCount: Int {
        switch self {
        case .doubleColorBall: 1
        case .superLotto: 2
        }
    }

    var tint: Color {
        switch self {
        case .doubleColorBall: AppTheme.Color.redBall
        case .superLotto: AppTheme.Color.primary
        }
    }
}

enum TicketStatus: String, Codable, CaseIterable {
    case pendingDraw
    case notWon
    case won
    case redeemed

    var displayName: String {
        switch self {
        case .pendingDraw: "待开奖"
        case .notWon: "未中奖"
        case .won: "已中奖"
        case .redeemed: "已兑奖"
        }
    }

    var tint: Color {
        switch self {
        case .pendingDraw: .orange
        case .notWon: .secondary
        case .won, .redeemed: AppTheme.Color.positive
        }
    }
}

@Model
final class LotteryDraw {
    @Attribute(.unique) var recordID: String
    var lotteryRawValue: String
    var issueNumber: String
    var drawDate: Date
    var frontNumbersRaw: String
    var backNumbersRaw: String
    var poolAmount: Double
    var sourceLabel: String

    init(kind: LotteryKind, issueNumber: String, drawDate: Date, frontNumbers: [Int], backNumbers: [Int], poolAmount: Double, sourceLabel: String = "内置演示数据") {
        self.recordID = "\(kind.rawValue)-\(issueNumber)"
        self.lotteryRawValue = kind.rawValue
        self.issueNumber = issueNumber
        self.drawDate = drawDate
        self.frontNumbersRaw = Self.encode(frontNumbers)
        self.backNumbersRaw = Self.encode(backNumbers)
        self.poolAmount = poolAmount
        self.sourceLabel = sourceLabel
    }

    var kind: LotteryKind { LotteryKind(rawValue: lotteryRawValue) ?? .doubleColorBall }
    var frontNumbers: [Int] { Self.decode(frontNumbersRaw) }
    var backNumbers: [Int] { Self.decode(backNumbersRaw) }

    static func encode(_ values: [Int]) -> String {
        values.sorted().map { String(format: "%02d", $0) }.joined(separator: ",")
    }

    static func decode(_ value: String) -> [Int] {
        value.split(separator: ",").compactMap { Int($0) }
    }
}

@Model
final class LotteryTicket {
    @Attribute(.unique) var id: UUID
    var lotteryRawValue: String
    var issueNumber: String
    var purchaseDate: Date
    var frontNumbersRaw: String
    var backNumbersRaw: String
    var multiplier: Int
    var isAdditional: Bool
    var statusRawValue: String
    var checkedAt: Date?
    var matchedFrontCount: Int
    var matchedBackCount: Int
    var prizeLevel: String?
    var estimatedPrize: Double

    init(kind: LotteryKind, issueNumber: String, frontNumbers: [Int], backNumbers: [Int], multiplier: Int = 1, isAdditional: Bool = false) {
        self.id = UUID()
        self.lotteryRawValue = kind.rawValue
        self.issueNumber = issueNumber
        self.purchaseDate = .now
        self.frontNumbersRaw = LotteryDraw.encode(frontNumbers)
        self.backNumbersRaw = LotteryDraw.encode(backNumbers)
        self.multiplier = multiplier
        self.isAdditional = isAdditional
        self.statusRawValue = TicketStatus.pendingDraw.rawValue
        self.matchedFrontCount = 0
        self.matchedBackCount = 0
        self.estimatedPrize = 0
    }

    var kind: LotteryKind { LotteryKind(rawValue: lotteryRawValue) ?? .doubleColorBall }
    var frontNumbers: [Int] { LotteryDraw.decode(frontNumbersRaw) }
    var backNumbers: [Int] { LotteryDraw.decode(backNumbersRaw) }
    var status: TicketStatus { TicketStatus(rawValue: statusRawValue) ?? .pendingDraw }
    var purchaseCost: Double { Double(multiplier * (isAdditional ? 3 : 2)) }
}
