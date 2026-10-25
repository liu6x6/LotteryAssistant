import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Binding var isPresentingTicketEntry: Bool
    @Binding var ticketEntryPrefill: TicketEntryPrefill?
    @State private var kind: LotteryKind = .doubleColorBall
    @State private var period: LuckyNumberPeriod = .oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Picker("彩种", selection: $kind) {
                    ForEach(LotteryKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Picker("统计周期", selection: $period) {
                    ForEach(LuckyNumberPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                LuckyNumberStatistics(kind: kind, period: period) { entry in
                    ticketEntryPrefill = TicketEntryPrefill(kind: kind, entries: [entry])
                    isPresentingTicketEntry = true
                }

                Label("统计结果仅反映历史开奖频次，不代表未来开奖结果。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("幸运数字统计")
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private enum LuckyNumberPeriod: String, CaseIterable, Identifiable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case twoYears
    case threeYears

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMonth: "1个月"
        case .threeMonths: "3个月"
        case .sixMonths: "6个月"
        case .oneYear: "1年"
        case .twoYears: "2年"
        case .threeYears: "3年"
        }
    }

    var startDate: Date {
        let date: Date?
        switch self {
        case .oneMonth:
            date = Calendar.current.date(byAdding: .month, value: -1, to: .now)
        case .threeMonths:
            date = Calendar.current.date(byAdding: .month, value: -3, to: .now)
        case .sixMonths:
            date = Calendar.current.date(byAdding: .month, value: -6, to: .now)
        case .oneYear:
            date = Calendar.current.date(byAdding: .year, value: -1, to: .now)
        case .twoYears:
            date = Calendar.current.date(byAdding: .year, value: -2, to: .now)
        case .threeYears:
            date = Calendar.current.date(byAdding: .year, value: -3, to: .now)
        }
        return date ?? .now
    }
}

private struct LuckyNumberStatistics: View {
    @Query private var draws: [LotteryDraw]
    let kind: LotteryKind
    let period: LuckyNumberPeriod
    let onUseRecommendation: (TicketNumberDraft) -> Void

    init(
        kind: LotteryKind,
        period: LuckyNumberPeriod,
        onUseRecommendation: @escaping (TicketNumberDraft) -> Void
    ) {
        let lotteryRawValue = kind.rawValue
        let startDate = period.startDate
        _draws = Query(
            filter: #Predicate {
                $0.lotteryRawValue == lotteryRawValue && $0.drawDate >= startDate
            },
            sort: \LotteryDraw.drawDate,
            order: .reverse
        )
        self.kind = kind
        self.period = period
        self.onUseRecommendation = onUseRecommendation
    }

    private var sections: [LuckyNumberSection] {
        switch kind {
        case .doubleColorBall:
            [
                LuckyNumberSection(title: "红球 01–16", range: 1...16, values: draws.flatMap(\.frontNumbers)),
                LuckyNumberSection(title: "红球 17–33", range: 17...33, values: draws.flatMap(\.frontNumbers)),
                LuckyNumberSection(title: "蓝球 01–16", range: 1...16, values: draws.flatMap(\.backNumbers))
            ]
        case .superLotto:
            [
                LuckyNumberSection(title: "前区 01–17", range: 1...17, values: draws.flatMap(\.frontNumbers)),
                LuckyNumberSection(title: "前区 18–35", range: 18...35, values: draws.flatMap(\.frontNumbers)),
                LuckyNumberSection(title: "后区 01–12", range: 1...12, values: draws.flatMap(\.backNumbers))
            ]
        }
    }

    private var topFrequencies: [LuckyNumberChartFrequency] {
        var frequencies: [LuckyNumberChartFrequency] = []
        for section in sections {
            for frequency in section.frequencies {
                frequencies.append(
                    LuckyNumberChartFrequency(
                        section: section.title,
                        number: frequency.number,
                        count: frequency.count
                    )
                )
            }
        }
        return frequencies
            .sorted {
                $0.count == $1.count ? $0.number < $1.number : $0.count > $1.count
            }
            .prefix(10)
            .map { $0 }
    }

    private var backZone: LuckyNumberSection {
        sections[2]
    }

    private var recommendedEntry: TicketNumberDraft? {
        guard sections.count == 3 else { return nil }

        let firstSectionCount: Int
        let secondSectionCount: Int
        let backSectionCount: Int
        switch kind {
        case .doubleColorBall:
            firstSectionCount = 3
            secondSectionCount = 3
            backSectionCount = 1
        case .superLotto:
            firstSectionCount = 3
            secondSectionCount = 2
            backSectionCount = 2
        }

        let front = Array(sections[0].topNumbers(count: firstSectionCount))
            + Array(sections[1].topNumbers(count: secondSectionCount))
        let back = Array(sections[2].topNumbers(count: backSectionCount))
        guard front.count == kind.frontCount, back.count == kind.backCount else { return nil }
        return TicketNumberDraft(frontNumbers: front.sorted(), backNumbers: back.sorted())
    }

    var body: some View {
        if draws.isEmpty {
            ContentUnavailableView(
                "暂无统计数据",
                systemImage: "chart.bar.xaxis",
                description: Text("所选周期内暂无 \(kind.displayName) 开奖数据。")
            )
            .appCard()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("共统计 \(draws.count) 期 \(period.title) 内开奖记录")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)

                if let recommendedEntry {
                    recommendationCard(recommendedEntry)
                }

                ForEach(sections) { section in
                    sectionChart(section)
                }

                backZoneFrequencyChart
                frequencyChart

                ForEach(sections) { section in
                    frequencyList(section)
                }
            }
        }
    }

    private func recommendationCard(_ entry: TicketNumberDraft) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("三区高频推荐")
                .font(.headline)
            Text(kind == .doubleColorBall
                 ? "红球两个区间各取 3 个高频号码，蓝球区取 1 个。"
                 : "前区两个区间分别取 3、2 个高频号码，后区取 2 个。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Color.secondaryText)
            NumberRow(frontNumbers: entry.frontNumbers, backNumbers: entry.backNumbers)
            Button {
                onUseRecommendation(entry)
            } label: {
                Label("录入推荐彩票", systemImage: "ticket.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .appCard()
    }

    private func sectionChart(_ section: LuckyNumberSection) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("\(section.title) · Top 6")
                .font(.headline)
            Chart(section.topFrequencies) { frequency in
                SectorMark(
                    angle: .value("出现次数", frequency.count),
                    innerRadius: .ratio(0.55),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("号码", frequency.label))
                .annotation(position: .overlay) {
                    Text(frequency.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .chartLegend(position: .bottom, alignment: .center)
            .frame(height: 210)
        }
        .appCard()
    }

    private var frequencyChart: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("全区高频号码 Top 10")
                .font(.headline)
            Chart(topFrequencies) { frequency in
                BarMark(
                    x: .value("号码", frequency.label),
                    y: .value("出现次数", frequency.count)
                )
                .foregroundStyle(by: .value("区间", frequency.section))
                .annotation(position: .top) {
                    Text("\(frequency.count)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
            }
            .chartLegend(position: .bottom, alignment: .center)
            .frame(height: 220)
        }
        .appCard()
    }

    private var backZoneFrequencyChart: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("\(backZone.title)高频号码 Top 6")
                .font(.headline)
            Chart(backZone.topFrequencies) { frequency in
                BarMark(
                    x: .value("号码", frequency.label),
                    y: .value("出现次数", frequency.count)
                )
                .foregroundStyle(AppTheme.Color.blueBall)
                .annotation(position: .top) {
                    Text("\(frequency.count)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
            }
            .frame(height: 210)
        }
        .appCard()
    }

    private func frequencyList(_ section: LuckyNumberSection) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(section.title)
                .font(.headline)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.xs), count: 2),
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(section.frequencies) { frequency in
                    HStack {
                        Text(frequency.label)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(frequency.count) 次")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.Color.secondaryText)
                    }
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(
                        AppTheme.Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    )
                }
            }
        }
        .appCard()
    }
}

private struct LuckyNumberSection: Identifiable {
    let title: String
    let range: ClosedRange<Int>
    let values: [Int]

    var id: String { title }

    var frequencies: [LuckyNumberFrequency] {
        range.map { number in
            LuckyNumberFrequency(number: number, count: values.filter { $0 == number }.count)
        }
        .sorted {
            $0.count == $1.count ? $0.number < $1.number : $0.count > $1.count
        }
    }

    var topFrequencies: [LuckyNumberFrequency] {
        Array(frequencies.prefix(6))
    }

    func topNumbers(count: Int) -> [Int] {
        Array(frequencies.prefix(count).map(\.number))
    }
}

private struct LuckyNumberFrequency: Identifiable {
    let number: Int
    let count: Int

    var id: Int { number }
    var label: String { String(format: "%02d", number) }
}

private struct LuckyNumberChartFrequency: Identifiable {
    let section: String
    let number: Int
    let count: Int

    var id: String { "\(section)-\(number)" }
    var label: String { String(format: "%02d", number) }
}
