import Foundation
import SwiftData

struct LotteryDrawPayload: Sendable {
    let lottery: LotteryKind
    let issueNumber: String
    let drawDate: Date
    let frontNumbers: [Int]
    let backNumbers: [Int]
    let poolAmount: Double
    let prizeAmounts: [PrizeAmount]
    let sourceLabel: String
}

protocol LotteryDataProviding: Sendable {
    var sourceLabel: String { get }
    func fetchDraws(includeHistory: Bool) async throws -> [LotteryDrawPayload]
}

enum LotteryDataProviderError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case noValidDraws

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "开奖数据格式无法识别。"
        case .httpStatus(let status):
            "开奖数据服务暂不可用（HTTP \(status)）。"
        case .noValidDraws:
            "本次未获取到可用开奖数据。"
        }
    }
}

struct OfficialLotteryDataProvider: LotteryDataProviding {
    let sourceLabel = "中国福利彩票 / 中国体育彩票"

    func fetchDraws(includeHistory: Bool) async throws -> [LotteryDrawPayload] {
        async let doubleColorBall = fetchDoubleColorBall(includeHistory: includeHistory)
        async let superLotto = fetchSuperLotto(includeHistory: includeHistory)
        return try await doubleColorBall + superLotto
    }

    private func fetchDoubleColorBall(includeHistory: Bool) async throws -> [LotteryDrawPayload] {
        let issueCount = includeHistory ? 2078 : 100
        let url = URL(string: "https://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice?name=ssq&issueCount=\(issueCount)")!
        let data = try await NetworkClient.data(from: url)
        let response = try JSONDecoder().decode(CWLDrawResponse.self, from: data)
        guard response.state == 0 else { throw LotteryDataProviderError.invalidResponse }

        return response.result.compactMap { draw in
            guard let date = DateParser.beijingDate(from: String(draw.date.prefix(10))),
                  let front = NumberParser.numbers(from: draw.red),
                  let back = NumberParser.numbers(from: draw.blue),
                  let pool = Double(draw.poolmoney) else {
                return nil
            }
            let prizeAmounts = draw.prizegrades.compactMap { grade -> PrizeAmount? in
                guard (1...6).contains(grade.type),
                      let amount = Double(grade.typemoney) else {
                    return nil
                }
                return PrizeAmount(level: PrizeLevel.name(for: grade.type), amount: amount)
            }
            return LotteryDrawPayload(
                lottery: .doubleColorBall,
                issueNumber: LotteryIssue.normalize(draw.code, for: .doubleColorBall),
                drawDate: date,
                frontNumbers: front,
                backNumbers: back,
                poolAmount: pool,
                prizeAmounts: prizeAmounts,
                sourceLabel: sourceLabel
            )
        }
    }

    private func fetchSuperLotto(includeHistory: Bool) async throws -> [LotteryDrawPayload] {
        let firstPage = try await fetchSuperLottoPage(number: 1)
        guard firstPage.success, let firstValue = firstPage.value else {
            throw LotteryDataProviderError.invalidResponse
        }

        var items = firstValue.list
        let pageCount = includeHistory ? max(1, Int(ceil(Double(firstValue.total) / 100))) : 1
        if pageCount > 1 {
            for page in 2...pageCount {
                let response = try await fetchSuperLottoPage(number: page)
                guard response.success, let value = response.value else {
                    throw LotteryDataProviderError.invalidResponse
                }
                items += value.list
                try await Task.sleep(for: .milliseconds(250))
            }
        }

        return items.compactMap { draw in
            guard let values = NumberParser.numbers(from: draw.lotteryDrawResult),
                  values.count == 7,
                  let date = DateParser.beijingDate(from: draw.lotteryDrawTime),
                  let pool = NumberParser.amount(from: draw.poolBalanceAfterdraw) else {
                return nil
            }
            let prizeAmounts = draw.prizeLevelList.compactMap { level -> PrizeAmount? in
                guard let amount = Double(level.stakeAmountFormat), amount > 0 else {
                    return nil
                }
                return PrizeAmount(level: level.prizeLevel, amount: amount)
            }
            return LotteryDrawPayload(
                lottery: .superLotto,
                issueNumber: LotteryIssue.normalize(draw.lotteryDrawNum, for: .superLotto),
                drawDate: date,
                frontNumbers: Array(values.prefix(5)),
                backNumbers: Array(values.suffix(2)),
                poolAmount: pool,
                prizeAmounts: prizeAmounts,
                sourceLabel: sourceLabel
            )
        }
    }

    private func fetchSuperLottoPage(number: Int) async throws -> SportteryHistoryResponse {
        let endpoint = "https://webapi.sporttery.cn/gateway/lottery/getHistoryPageListV1.qry?gameNo=85&provinceId=0&pageSize=100&isVerify=1&pageNo=\(number)"
        guard let url = URL(string: endpoint) else { throw LotteryDataProviderError.invalidResponse }
        let data = try await NetworkClient.data(
            from: url,
            headers: ["Referer": "https://static.sporttery.cn/"]
        )
        return try JSONDecoder().decode(SportteryHistoryResponse.self, from: data)
    }
}

struct FallbackLotteryDataProvider: LotteryDataProviding {
    let primary: any LotteryDataProviding
    let fallback: any LotteryDataProviding

    var sourceLabel: String { primary.sourceLabel }

    func fetchDraws(includeHistory: Bool) async throws -> [LotteryDrawPayload] {
        do {
            return try await primary.fetchDraws(includeHistory: includeHistory)
        } catch {
            return try await fallback.fetchDraws(includeHistory: includeHistory)
        }
    }
}

struct YangLotteryDataProvider: LotteryDataProviding {
    let sourceLabel = "GitHub 开源镜像（yangxb919/lottery-data）"

    func fetchDraws(includeHistory: Bool) async throws -> [LotteryDrawPayload] {
        async let ssqData = NetworkClient.data(
            fromAny: [
                URL(string: "https://cdn.jsdelivr.net/gh/yangxb919/lottery-data@main/data/ssq.json")!,
                URL(string: "https://raw.githubusercontent.com/yangxb919/lottery-data/main/data/ssq.json")!
            ]
        )
        async let dltData = NetworkClient.data(
            fromAny: [
                URL(string: "https://cdn.jsdelivr.net/gh/yangxb919/lottery-data@main/data/dlt.json")!,
                URL(string: "https://raw.githubusercontent.com/yangxb919/lottery-data/main/data/dlt.json")!
            ]
        )
        let (ssqResponseData, dltResponseData) = try await (ssqData, dltData)
        let decoder = JSONDecoder()
        let ssq = try decoder.decode([YangSSQDraw].self, from: ssqResponseData)
        let dlt = try decoder.decode([YangDLTDraw].self, from: dltResponseData)

        let doubleColorBall = ssq.compactMap { draw -> LotteryDrawPayload? in
            guard let date = DateParser.beijingDate(from: draw.date),
                  let front = NumberParser.numbers(from: draw.red),
                  let back = NumberParser.numbers(from: draw.blue) else {
                return nil
            }
            return LotteryDrawPayload(
                lottery: .doubleColorBall,
                issueNumber: LotteryIssue.normalize(draw.issue, for: .doubleColorBall),
                drawDate: date,
                frontNumbers: front,
                backNumbers: back,
                poolAmount: 0,
                prizeAmounts: [],
                sourceLabel: sourceLabel
            )
        }
        let superLotto = dlt.compactMap { draw -> LotteryDrawPayload? in
            guard let date = DateParser.beijingDate(from: draw.date),
                  let front = NumberParser.numbers(from: draw.front),
                  let back = NumberParser.numbers(from: draw.back) else {
                return nil
            }
            return LotteryDrawPayload(
                lottery: .superLotto,
                issueNumber: LotteryIssue.normalize(draw.issue, for: .superLotto),
                drawDate: date,
                frontNumbers: front,
                backNumbers: back,
                poolAmount: 0,
                prizeAmounts: [],
                sourceLabel: sourceLabel
            )
        }
        return doubleColorBall + superLotto
    }
}

@MainActor
struct DrawSyncService {
    let provider: any LotteryDataProviding

    func synchronize(
        context: ModelContext,
        isDoubleColorBallFortunePrizeEnabled: Bool = false
    ) async throws -> Int {
        let existingRecords = try context.fetch(FetchDescriptor<LotteryDraw>())
        let payloads = try await provider.fetchDraws(includeHistory: existingRecords.isEmpty)
        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.recordID, $0) })
        var insertedCount = 0

        for payload in payloads {
            let normalizedIssue = LotteryIssue.normalize(payload.issueNumber, for: payload.lottery)
            let recordID = "\(payload.lottery.rawValue)-\(normalizedIssue)"
            guard isValid(payload: payload) else { continue }

            if let existing = recordsByID[recordID] {
                if existing.poolAmount == 0, payload.poolAmount > 0 {
                    existing.poolAmount = payload.poolAmount
                    existing.sourceLabel = payload.sourceLabel
                }
                if existing.prizeAmounts.isEmpty, !payload.prizeAmounts.isEmpty {
                    existing.prizeAmountsRaw = PrizeAmountCodec.encode(payload.prizeAmounts)
                }
                continue
            }

            let draw = LotteryDraw(
                kind: payload.lottery,
                issueNumber: normalizedIssue,
                drawDate: payload.drawDate,
                frontNumbers: payload.frontNumbers,
                backNumbers: payload.backNumbers,
                poolAmount: payload.poolAmount,
                prizeAmounts: payload.prizeAmounts,
                sourceLabel: payload.sourceLabel
            )
            context.insert(draw)
            recordsByID[recordID] = draw
            insertedCount += 1
        }

        guard !payloads.isEmpty else { throw LotteryDataProviderError.noValidDraws }
        try updateTicketResults(
            context: context,
            drawsByRecordID: recordsByID,
            isDoubleColorBallFortunePrizeEnabled: isDoubleColorBallFortunePrizeEnabled
        )
        try context.save()
        return insertedCount
    }

    private func isValid(payload: LotteryDrawPayload) -> Bool {
        let kind = payload.lottery
        return payload.frontNumbers.count == kind.frontCount
            && payload.backNumbers.count == kind.backCount
            && Set(payload.frontNumbers).count == payload.frontNumbers.count
            && Set(payload.backNumbers).count == payload.backNumbers.count
            && payload.frontNumbers.allSatisfy(kind.frontRange.contains)
            && payload.backNumbers.allSatisfy(kind.backRange.contains)
    }

    private func updateTicketResults(
        context: ModelContext,
        drawsByRecordID: [String: LotteryDraw],
        isDoubleColorBallFortunePrizeEnabled: Bool
    ) throws {
        let tickets = try context.fetch(FetchDescriptor<LotteryTicket>())
        for ticket in tickets where ticket.status == .pendingDraw {
            let recordID = "\(ticket.kind.rawValue)-\(LotteryIssue.normalize(ticket.issueNumber, for: ticket.kind))"
            guard let draw = drawsByRecordID[recordID] else { continue }
            PrizeChecker.apply(
                PrizeChecker.evaluate(
                    ticket: ticket,
                    draw: draw,
                    isDoubleColorBallFortunePrizeEnabled: isDoubleColorBallFortunePrizeEnabled
                ),
                to: ticket,
                using: draw
            )
        }
    }
}

private enum PrizeLevel {
    static func name(for type: Int) -> String {
        ["", "一等奖", "二等奖", "三等奖", "四等奖", "五等奖", "六等奖"][type]
    }
}

enum LotteryIssue {
    static func normalize(_ value: String, for kind: LotteryKind) -> String {
        let digits = value.filter(\.isNumber)
        switch kind {
        case .doubleColorBall:
            return digits.count == 5 ? "20\(digits)" : digits
        case .superLotto:
            return digits.count == 7 ? String(digits.dropFirst(2)) : digits
        }
    }
}

private enum NetworkClient {
    static func data(fromAny urls: [URL]) async throws -> Data {
        var lastError: Error?
        for url in urls {
            do {
                return try await data(from: url)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? LotteryDataProviderError.invalidResponse
    }

    static func data(from url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LotteryDataProviderError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw LotteryDataProviderError.httpStatus(httpResponse.statusCode)
        }
        return data
    }
}

private enum NumberParser {
    static func numbers(from value: String) -> [Int]? {
        let numbers = value
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .compactMap { Int($0) }
        return numbers.isEmpty ? nil : numbers
    }

    static func numbers(from values: [String]) -> [Int]? {
        let numbers = values.compactMap(Int.init)
        return numbers.count == values.count ? numbers : nil
    }

    static func amount(from value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: ""))
    }
}

private enum DateParser {
    static func beijingDate(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private struct CWLDrawResponse: Decodable {
    let state: Int
    let result: [CWLDraw]
}

private struct CWLDraw: Decodable {
    let code: String
    let date: String
    let red: String
    let blue: String
    let poolmoney: String
    let prizegrades: [CWLPrizeGrade]
}

private struct CWLPrizeGrade: Decodable {
    let type: Int
    let typemoney: String
}

private struct SportteryHistoryResponse: Decodable {
    let success: Bool
    let value: SportteryHistoryValue?
}

private struct SportteryHistoryValue: Decodable {
    let total: Int
    let list: [SportteryDraw]
}

private struct SportteryDraw: Decodable {
    let lotteryDrawNum: String
    let lotteryDrawTime: String
    let lotteryDrawResult: String
    let poolBalanceAfterdraw: String
    let prizeLevelList: [SportteryPrizeLevel]
}

private struct SportteryPrizeLevel: Decodable {
    let prizeLevel: String
    let stakeAmountFormat: String
}

private struct YangSSQDraw: Decodable {
    let issue: String
    let date: String
    let red: [String]
    let blue: [String]
}

private struct YangDLTDraw: Decodable {
    let issue: String
    let date: String
    let front: [String]
    let back: [String]
}
