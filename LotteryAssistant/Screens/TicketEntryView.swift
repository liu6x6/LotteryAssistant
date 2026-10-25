import SwiftUI
import SwiftData

struct TicketEntryPrefill {
    let kind: LotteryKind
    let entries: [TicketNumberDraft]
}

struct TicketEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(LotteryRuleSettings.isDoubleColorBallFortunePrizeEnabled)
    private var isDoubleColorBallFortunePrizeEnabled = false
    @Query(sort: \LotteryDraw.drawDate, order: .reverse) private var draws: [LotteryDraw]
    @Query private var existingTickets: [LotteryTicket]

    private let ticket: LotteryTicket?
    private let prefill: TicketEntryPrefill?

    @State private var kind: LotteryKind
    @State private var issueNumber: String
    @State private var frontNumbers: Set<Int>
    @State private var backNumbers: Set<Int>
    @State private var multiplier: Int
    @State private var isAdditional: Bool
    @State private var validationMessage: String?
    @State private var isPresentingScanner = false
    @State private var additionalScannedEntries: [TicketNumberDraft] = []

    init(ticket: LotteryTicket? = nil, prefill: TicketEntryPrefill? = nil) {
        self.ticket = ticket
        self.prefill = prefill
        let initialEntry = prefill?.entries.first
        _kind = State(initialValue: ticket?.kind ?? prefill?.kind ?? .doubleColorBall)
        _issueNumber = State(initialValue: ticket?.issueNumber ?? "")
        _frontNumbers = State(initialValue: Set(ticket?.frontNumbers ?? initialEntry?.frontNumbers ?? []))
        _backNumbers = State(initialValue: Set(ticket?.backNumbers ?? initialEntry?.backNumbers ?? []))
        _multiplier = State(initialValue: ticket?.multiplier ?? 1)
        _isAdditional = State(initialValue: ticket?.isAdditional ?? false)
        _additionalScannedEntries = State(initialValue: ticket == nil ? Array(prefill?.entries.dropFirst() ?? []) : [])
    }

    private var latestIssue: String {
        draws.first(where: { $0.kind == kind })?.issueNumber ?? ""
    }

    var body: some View {
        Form {
            Section("彩票信息") {
                Picker("彩种", selection: $kind) {
                    ForEach(LotteryKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .onChange(of: kind) {
                    clearNumbers()
                    issueNumber = latestIssue
                }

                TextField("开奖期号", text: $issueNumber)
                    .keyboardType(.numberPad)

                Stepper("投注倍数：\(multiplier) 倍", value: $multiplier, in: 1...99)

                if kind == .superLotto {
                    Toggle("追加投注", isOn: $isAdditional)
                }
            }

            Section {
                Button {
                    isPresentingScanner = true
                } label: {
                    Label("扫描或导入票据", systemImage: "doc.text.viewfinder")
                }
            } footer: {
                Text("识别出的内容必须由您确认后才会保存。")
            }

            if !additionalScannedEntries.isEmpty {
                Section {
                    ForEach(additionalScannedEntries) { entry in
                        HStack {
                            NumberRow(
                                frontNumbers: entry.frontNumbers,
                                backNumbers: entry.backNumbers
                            )
                            Spacer()
                            Button(role: .destructive) {
                                additionalScannedEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("删除该注号码")
                        }
                    }
                } header: {
                    Text("OCR 识别的其他号码")
                } footer: {
                    Text("保存时，每一注号码都会创建为一张独立彩票，并使用相同的期号、倍数和追加设置。")
                }
            }

            Section {
                NumberPickerGrid(
                    title: kind == .doubleColorBall ? "选择 6 个红球" : "选择 5 个前区号码",
                    range: kind.frontRange,
                    color: AppTheme.Color.redBall,
                    selection: $frontNumbers,
                    maximum: kind.frontCount
                )
            }

            Section {
                NumberPickerGrid(
                    title: kind == .doubleColorBall ? "选择 1 个蓝球" : "选择 2 个后区号码",
                    range: kind.backRange,
                    color: AppTheme.Color.blueBall,
                    selection: $backNumbers,
                    maximum: kind.backCount
                )
            }

            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.Color.error)
                }
            }
        }
        .navigationTitle(ticket == nil ? "录入彩票" : "修改彩票")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveTicket() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            if issueNumber.isEmpty {
                issueNumber = latestIssue
            }
        }
        .sheet(isPresented: $isPresentingScanner) {
            TicketScanView(kind: kind) { draft in
                guard let firstEntry = draft.entries.first else { return }
                frontNumbers = Set(firstEntry.frontNumbers)
                backNumbers = Set(firstEntry.backNumbers)
                additionalScannedEntries = ticket == nil ? Array(draft.entries.dropFirst()) : []
                if !draft.issueNumber.isEmpty {
                    issueNumber = draft.issueNumber
                }
                if ticket != nil, draft.entries.count > 1 {
                    validationMessage = "修改彩票时仅应用识别结果中的第一注号码。"
                }
            }
        }
    }

    private func clearNumbers() {
        frontNumbers.removeAll()
        backNumbers.removeAll()
        additionalScannedEntries.removeAll()
        isAdditional = false
    }

    private func saveTicket() {
        let trimmedIssue = issueNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIssue.isEmpty else {
            validationMessage = "请输入开奖期号。"
            return
        }
        guard frontNumbers.count == kind.frontCount else {
            validationMessage = "请准确选择 \(kind.frontCount) 个前区号码。"
            return
        }
        guard backNumbers.count == kind.backCount else {
            validationMessage = "请准确选择 \(kind.backCount) 个后区号码。"
            return
        }

        let normalizedIssue = LotteryIssue.normalize(trimmedIssue, for: kind)
        let primaryEntry = TicketNumberDraft(
            frontNumbers: frontNumbers.sorted(),
            backNumbers: backNumbers.sorted()
        )
        let usesAdditional = kind == .superLotto && isAdditional

        if let ticket {
            let editedSignature = TicketSignature(
                kind: kind,
                issueNumber: normalizedIssue,
                entry: primaryEntry,
                multiplier: multiplier,
                isAdditional: usesAdditional
            )
            guard !existingTickets.contains(where: {
                $0.id != ticket.id && TicketSignature(ticket: $0) == editedSignature
            }) else {
                validationMessage = "相同彩票已经存在，请修改号码或投注信息。"
                return
            }

            ticket.lotteryRawValue = kind.rawValue
            ticket.issueNumber = normalizedIssue
            ticket.frontNumbersRaw = LotteryDraw.encode(primaryEntry.frontNumbers)
            ticket.backNumbersRaw = LotteryDraw.encode(primaryEntry.backNumbers)
            ticket.multiplier = multiplier
            ticket.isAdditional = usesAdditional
            ticket.statusRawValue = TicketStatus.pendingDraw.rawValue
            ticket.checkedAt = nil
            ticket.matchedFrontCount = 0
            ticket.matchedBackCount = 0
            ticket.prizeLevel = nil
            ticket.estimatedPrize = 0
            applyResultIfAvailable(to: ticket, issueNumber: normalizedIssue)
        } else {
            let entries = [primaryEntry] + additionalScannedEntries
            var knownSignatures = Set(existingTickets.map(TicketSignature.init(ticket:)))
            var uniqueEntries: [TicketNumberDraft] = []

            for entry in entries {
                let signature = TicketSignature(
                    kind: kind,
                    issueNumber: normalizedIssue,
                    entry: entry,
                    multiplier: multiplier,
                    isAdditional: usesAdditional
                )
                if knownSignatures.insert(signature).inserted {
                    uniqueEntries.append(entry)
                }
            }

            guard !uniqueEntries.isEmpty else {
                validationMessage = "相同彩票已经存在，本次没有重复添加。"
                return
            }

            for entry in uniqueEntries {
                let newTicket = LotteryTicket(
                    kind: kind,
                    issueNumber: normalizedIssue,
                    frontNumbers: entry.frontNumbers,
                    backNumbers: entry.backNumbers,
                    multiplier: multiplier,
                    isAdditional: usesAdditional
                )
                applyResultIfAvailable(to: newTicket, issueNumber: normalizedIssue)
                modelContext.insert(newTicket)
            }
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            validationMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func applyResultIfAvailable(to ticket: LotteryTicket, issueNumber: String) {
        guard let draw = draws.first(where: {
            $0.kind == kind && LotteryIssue.normalize($0.issueNumber, for: kind) == issueNumber
        }) else {
            return
        }
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

private struct TicketSignature: Hashable {
    let lotteryRawValue: String
    let issueNumber: String
    let frontNumbersRaw: String
    let backNumbersRaw: String
    let multiplier: Int
    let isAdditional: Bool

    init(
        kind: LotteryKind,
        issueNumber: String,
        entry: TicketNumberDraft,
        multiplier: Int,
        isAdditional: Bool
    ) {
        self.lotteryRawValue = kind.rawValue
        self.issueNumber = LotteryIssue.normalize(issueNumber, for: kind)
        self.frontNumbersRaw = LotteryDraw.encode(entry.frontNumbers)
        self.backNumbersRaw = LotteryDraw.encode(entry.backNumbers)
        self.multiplier = multiplier
        self.isAdditional = isAdditional
    }

    init(ticket: LotteryTicket) {
        self.init(
            kind: ticket.kind,
            issueNumber: ticket.issueNumber,
            entry: TicketNumberDraft(
                frontNumbers: ticket.frontNumbers,
                backNumbers: ticket.backNumbers
            ),
            multiplier: ticket.multiplier,
            isAdditional: ticket.isAdditional
        )
    }
}

private struct NumberPickerGrid: View {
    let title: String
    let range: ClosedRange<Int>
    let color: Color
    @Binding var selection: Set<Int>
    let maximum: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.xs), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(selection.count)/\(maximum)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(selection.count == maximum ? AppTheme.Color.positive : AppTheme.Color.secondaryText)
            }
            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
                ForEach(Array(range), id: \.self) { number in
                    Button {
                        toggle(number)
                    } label: {
                        NumberBall(number: number, color: color, isSelected: selection.contains(number))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(selection.contains(number) ? "再次轻点取消选择" : "轻点选择号码")
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }

    private func toggle(_ number: Int) {
        if selection.contains(number) {
            selection.remove(number)
        } else if selection.count < maximum {
            selection.insert(number)
        }
    }
}
