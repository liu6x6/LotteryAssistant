import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Binding var isPresentingTicketEntry: Bool
    @Binding var ticketEntryPrefill: TicketEntryPrefill?
    @AppStorage(SimulationMode.activeGroupIDKey) private var activeSimulationGroupID = ""
    @State private var kind: LotteryKind = .doubleColorBall
    @State private var periodUnit: LuckyNumberPeriod.Unit = .month
    @State private var periodValue = 1

    private var period: LuckyNumberPeriod {
        LuckyNumberPeriod(unit: periodUnit, value: periodValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Picker("彩种", selection: $kind) {
                    ForEach(LotteryKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                LuckyNumberPeriodPicker(unit: $periodUnit, value: $periodValue)

                LuckyNumberStatistics(
                    kind: kind,
                    period: period,
                    isSimulationMode: !activeSimulationGroupID.isEmpty
                ) { entry in
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PositionNumberDistributionView()
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                }
                .accessibilityLabel("查看各位置号码分布")
            }
        }
    }
}

private struct LuckyNumberPeriod: Hashable {
    enum Unit: String, CaseIterable, Identifiable {
        case month
        case year

        var id: String { rawValue }
        var title: String { self == .month ? "月" : "年" }
        var maximumValue: Int { self == .month ? 11 : 3 }
    }

    let unit: Unit
    let value: Int

    var title: String { "\(value)\(unit.title)" }

    var startDate: Date {
        let component: Calendar.Component = unit == .month ? .month : .year
        return Calendar.current.date(byAdding: component, value: -value, to: .now) ?? .now
    }
}

private struct LuckyNumberPeriodPicker: View {
    @Binding var unit: LuckyNumberPeriod.Unit
    @Binding var value: Int

    var body: some View {
        HStack {
            Picker("单位", selection: $unit) {
                ForEach(LuckyNumberPeriod.Unit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .pickerStyle(.segmented)

            Picker("统计周期", selection: $value) {
                ForEach(1...unit.maximumValue, id: \.self) { value in
                    Text("\(value)\(unit.title)").tag(value)
                }
            }
            .pickerStyle(.menu)
        }
        .onChange(of: unit) {
            value = min(value, unit.maximumValue)
        }
    }
}

private struct PositionNumberDistributionView: View {
    @State private var kind: LotteryKind = .doubleColorBall
    @State private var periodUnit: LuckyNumberPeriod.Unit = .month
    @State private var periodValue = 1

    private var period: LuckyNumberPeriod {
        LuckyNumberPeriod(unit: periodUnit, value: periodValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Picker("彩种", selection: $kind) {
                    ForEach(LotteryKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                LuckyNumberPeriodPicker(unit: $periodUnit, value: $periodValue)

                PositionNumberDistribution(kind: kind, period: period)

                Label("曲线反映各号码在对应位置的历史出现频次，不代表未来开奖结果。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("各位置号码分布")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct PositionNumberDistribution: View {
    @Query private var draws: [LotteryDraw]
    let kind: LotteryKind
    let period: LuckyNumberPeriod

    init(kind: LotteryKind, period: LuckyNumberPeriod) {
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
    }

    private var sections: [PositionDistributionSection] {
        let frontTitle = kind == .doubleColorBall ? "红球" : "前区"
        let backTitle = kind == .doubleColorBall ? "蓝球" : "后区"

        return (0..<kind.frontCount).map { index in
            PositionDistributionSection(
                title: "\(frontTitle)第 \(index + 1) 位",
                range: kind.frontRange,
                values: draws.compactMap { draw in
                    draw.frontNumbers.indices.contains(index) ? draw.frontNumbers[index] : nil
                },
                color: AppTheme.Color.redBall
            )
        } + (0..<kind.backCount).map { index in
            PositionDistributionSection(
                title: "\(backTitle)第 \(index + 1) 位",
                range: kind.backRange,
                values: draws.compactMap { draw in
                    draw.backNumbers.indices.contains(index) ? draw.backNumbers[index] : nil
                },
                color: AppTheme.Color.blueBall
            )
        }
    }

    var body: some View {
        if draws.isEmpty {
            ContentUnavailableView(
                "暂无统计数据",
                systemImage: "chart.xyaxis.line",
                description: Text("所选周期内暂无 \(kind.displayName) 开奖数据。")
            )
            .appCard()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("共统计 \(draws.count) 期 \(period.title) 内开奖记录")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)

                ForEach(sections) { section in
                    positionChart(section)
                }
            }
        }
    }

    private func positionChart(_ section: PositionDistributionSection) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(section.title)
                .font(.headline)
            Text("历史频次")
                .font(.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
            Chart(section.observedFrequencies) { frequency in
                AreaMark(
                    x: .value("号码", frequency.number),
                    y: .value("出现次数", frequency.count)
                )
                .foregroundStyle(section.color.opacity(0.18))

                LineMark(
                    x: .value("号码", frequency.number),
                    y: .value("出现次数", frequency.count)
                )
                .foregroundStyle(section.color)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("号码", frequency.number),
                    y: .value("出现次数", frequency.count)
                )
                .foregroundStyle(section.color)
            }
            .chartXAxis {
                AxisMarks(values: section.observedNumbers) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let number = value.as(Int.self) {
                            Text(String(format: "%02d", number))
                        }
                    }
                }
            }
            .chartXScale(domain: section.xScaleDomain)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 8)
            .frame(height: 180)

            Divider()

            Text("正态分布拟合 · 均值 \(section.mean.formatted(.number.precision(.fractionLength(1))))")
                .font(.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
            Chart(section.normalDistribution) { point in
                AreaMark(
                    x: .value("号码", point.number),
                    y: .value("相对密度", point.density)
                )
                .foregroundStyle(section.color.opacity(0.25))

                LineMark(
                    x: .value("号码", point.number),
                    y: .value("相对密度", point.density)
                )
                .foregroundStyle(section.color)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: section.observedNumbers) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let number = value.as(Int.self) {
                            Text(String(format: "%02d", number))
                        }
                    }
                }
            }
            .chartXScale(domain: section.xScaleDomain)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 8)
            .chartYScale(domain: 0...1)
            .frame(height: 180)
        }
        .appCard()
    }
}

private struct PositionDistributionSection: Identifiable {
    let title: String
    let range: ClosedRange<Int>
    let values: [Int]
    let color: Color

    var id: String { title }

    var frequencies: [LuckyNumberFrequency] {
        range.map { number in
            LuckyNumberFrequency(number: number, count: values.filter { $0 == number }.count)
        }
    }

    var observedFrequencies: [LuckyNumberFrequency] {
        frequencies.filter { $0.count > 0 }
    }

    var observedNumbers: [Int] {
        observedFrequencies.map(\.number)
    }

    var xScaleDomain: ClosedRange<Int> {
        guard let minimum = observedNumbers.min(), let maximum = observedNumbers.max() else {
            return range
        }

        let lowerBound = max(range.lowerBound, minimum - 1)
        let upperBound = min(range.upperBound, maximum + 1)
        return lowerBound == upperBound ? lowerBound...(upperBound + 1) : lowerBound...upperBound
    }

    var mean: Double {
        guard !values.isEmpty else { return 0 }
        return values.map(Double.init).reduce(0, +) / Double(values.count)
    }

    var normalDistribution: [NormalDistributionPoint] {
        let variance = values
            .map { pow(Double($0) - mean, 2) }
            .reduce(0, +) / Double(max(values.count, 1))
        let standardDeviation = max(sqrt(variance), 0.5)

        return observedNumbers.map { number in
            let normalizedDistance = (Double(number) - mean) / standardDeviation
            return NormalDistributionPoint(
                number: number,
                density: exp(-0.5 * normalizedDistance * normalizedDistance)
            )
        }
    }
}

private struct NormalDistributionPoint: Identifiable {
    let number: Int
    let density: Double

    var id: Int { number }
}

private struct LuckyNumberStatistics: View {
    @Query private var draws: [LotteryDraw]
    let kind: LotteryKind
    let period: LuckyNumberPeriod
    let isSimulationMode: Bool
    let onUseRecommendation: (TicketNumberDraft) -> Void

    init(
        kind: LotteryKind,
        period: LuckyNumberPeriod,
        isSimulationMode: Bool,
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
        self.isSimulationMode = isSimulationMode
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
                Label(isSimulationMode ? "加入模拟组" : "录入推荐彩票", systemImage: "ticket.fill")
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
