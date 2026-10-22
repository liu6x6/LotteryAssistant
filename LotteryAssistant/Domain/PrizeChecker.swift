import Foundation

struct PrizeEvaluation {
    let matchedFrontCount: Int
    let matchedBackCount: Int
    let prizeLevel: String?

    var isWinner: Bool { prizeLevel != nil }
}

enum PrizeChecker {
    static func evaluate(ticket: LotteryTicket, draw: LotteryDraw) -> PrizeEvaluation {
        let front = Set(ticket.frontNumbers).intersection(draw.frontNumbers).count
        let back = Set(ticket.backNumbers).intersection(draw.backNumbers).count
        let level: String?

        switch ticket.kind {
        case .doubleColorBall:
            switch (front, back) {
            case (6, 1): level = "一等奖"
            case (6, 0): level = "二等奖"
            case (5, 1): level = "三等奖"
            case (5, 0), (4, 1): level = "四等奖"
            case (4, 0), (3, 1): level = "五等奖"
            case (0...2, 1): level = "六等奖"
            default: level = nil
            }
        case .superLotto:
            switch (front, back) {
            case (5, 2): level = "一等奖"
            case (5, 1): level = "二等奖"
            case (5, 0), (4, 2): level = "三等奖"
            case (4, 1): level = "四等奖"
            case (4, 0), (3, 2): level = "五等奖"
            case (3, 1), (2, 2): level = "六等奖"
            case (3, 0), (2, 1), (1, 2), (0, 2): level = "七等奖"
            default: level = nil
            }
        }

        return PrizeEvaluation(matchedFrontCount: front, matchedBackCount: back, prizeLevel: level)
    }

    static func apply(_ evaluation: PrizeEvaluation, to ticket: LotteryTicket) {
        ticket.matchedFrontCount = evaluation.matchedFrontCount
        ticket.matchedBackCount = evaluation.matchedBackCount
        ticket.prizeLevel = evaluation.prizeLevel
        ticket.estimatedPrize = 0
        ticket.checkedAt = .now
        ticket.statusRawValue = evaluation.isWinner ? TicketStatus.won.rawValue : TicketStatus.notWon.rawValue
    }
}
