import SwiftUI
import SwiftData

struct TicketEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LotteryDraw.drawDate, order: .reverse) private var draws: [LotteryDraw]

    @State private var kind: LotteryKind = .doubleColorBall
    @State private var issueNumber = ""
    @State private var frontNumbers = Set<Int>()
    @State private var backNumbers = Set<Int>()
    @State private var multiplier = 1
    @State private var isAdditional = false
    @State private var validationMessage: String?
    @State private var isPresentingScanner = false

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
        .navigationTitle("录入彩票")
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
                frontNumbers = Set(draft.frontNumbers)
                backNumbers = Set(draft.backNumbers)
                if !draft.issueNumber.isEmpty {
                    issueNumber = draft.issueNumber
                }
            }
        }
    }

    private func clearNumbers() {
        frontNumbers.removeAll()
        backNumbers.removeAll()
        isAdditional = false
    }

    private func saveTicket() {
        guard !issueNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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

        let ticket = LotteryTicket(
            kind: kind,
            issueNumber: issueNumber,
            frontNumbers: frontNumbers.sorted(),
            backNumbers: backNumbers.sorted(),
            multiplier: multiplier,
            isAdditional: isAdditional
        )

        if let draw = draws.first(where: { $0.kind == kind && $0.issueNumber == issueNumber }) {
            PrizeChecker.apply(PrizeChecker.evaluate(ticket: ticket, draw: draw), to: ticket, using: draw)
        }

        modelContext.insert(ticket)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationMessage = "保存失败：\(error.localizedDescription)"
        }
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
