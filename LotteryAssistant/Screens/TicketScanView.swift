import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Vision

struct TicketScanDraft {
    let issueNumber: String
    let entries: [TicketNumberDraft]
    let confidence: Float
}

struct TicketNumberDraft: Identifiable {
    let id = UUID()
    let frontNumbers: [Int]
    let backNumbers: [Int]
}

private struct RecognizedLine: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
}

private struct TicketScanAnalysis {
    let lines: [RecognizedLine]
    let issueNumber: String
    let entries: [TicketNumberDraft]

    var confidence: Float {
        guard !lines.isEmpty else { return 0 }
        return lines.map(\.confidence).reduce(0, +) / Float(lines.count)
    }
}

struct TicketScanView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LotteryKind
    let onApply: (TicketScanDraft) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var isPresentingCamera = false
    @State private var isPresentingBarcodeScanner = false
    @State private var analysis: TicketScanAnalysis?
    @State private var issueNumber = ""
    @State private var editableEntries: [EditableScannedEntry] = []
    @State private var isRecognizing = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    introduction
                    captureActions

                    if isRecognizing {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            ProgressView()
                            Text("正在识别票据文字…")
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let analysis {
                        confirmationCard(analysis: analysis)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Color.error)
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .navigationTitle("扫描票据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: selectedItem) {
                Task { await recognizeSelectedPhoto() }
            }
            .onChange(of: cameraImage) {
                Task { await recognizeCameraImage() }
            }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                CameraImagePicker(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $isPresentingBarcodeScanner) {
                BarcodeScannerView()
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "doc.text.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Color.primary)
            Text("识别彩票号码")
                .font(.title2.bold())
            Text("请将票据平码区域拍清楚。识别结果必须由您确认和修改后才会写入彩票。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .appCard()
    }

    private var captureActions: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        isPresentingCamera = true
                    } label: {
                        Label("拍摄", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("相册", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button {
                isPresentingBarcodeScanner = true
            } label: {
                Label("扫描票面条形码", systemImage: "barcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func confirmationCard(analysis: TicketScanAnalysis) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("确认识别结果")
                    .font(.headline)
                Spacer()
                confidenceBadge(analysis.confidence)
            }

            TextField("开奖期号", text: $issueNumber)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Text("共识别到 \(editableEntries.count) 注号码，保存后会自动拆分为 \(editableEntries.count) 张彩票。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Color.secondaryText)

            ForEach($editableEntries) { $entry in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    HStack {
                        Text("第 \(entry.sequence) 注")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if editableEntries.count > 1 {
                            Button(role: .destructive) {
                                editableEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("删除第 \(entry.sequence) 注")
                        }
                    }

                    TextField(
                        kind == .doubleColorBall ? "红球，例如：01 07 13 22 31 33" : "前区，例如：01 07 13 22 31",
                        text: $entry.frontNumbersText
                    )
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        kind == .doubleColorBall ? "蓝球，例如：08" : "后区，例如：03 11",
                        text: $entry.backNumbersText
                    )
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                }
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Color.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.error)
            }

            Button("应用已确认的号码") {
                applyDraft(confidence: analysis.confidence)
            }
            .buttonStyle(PrimaryButtonStyle())

            DisclosureGroup("查看识别文本") {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ForEach(analysis.lines) { line in
                        HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                            Text(line.text)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                            Spacer()
                            Text("\(Int(line.confidence * 100))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                    }
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
            .font(.subheadline)
        }
        .appCard()
    }

    private func confidenceBadge(_ confidence: Float) -> some View {
        let isReliable = confidence >= 0.8
        return Label(isReliable ? "识别清晰" : "请仔细核对", systemImage: isReliable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isReliable ? AppTheme.Color.positive : AppTheme.Color.accent)
    }

    @MainActor
    private func recognizeSelectedPhoto() async {
        guard let selectedItem else { return }
        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取这张图片，请换一张清晰的票据照片。"
                return
            }
            await analyze(image)
        } catch {
            errorMessage = "读取相册图片失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func recognizeCameraImage() async {
        guard let cameraImage else { return }
        await analyze(cameraImage)
    }

    @MainActor
    private func analyze(_ image: UIImage) async {
        guard let cgImage = image.cgImage else {
            errorMessage = "图片格式不受支持，请重新拍摄或选择原始照片。"
            return
        }

        isRecognizing = true
        errorMessage = nil
        validationMessage = nil
        defer { isRecognizing = false }

        do {
            let lines = try await recognizeLines(in: cgImage, orientation: image.cgImagePropertyOrientation)
            guard !lines.isEmpty else {
                analysis = nil
                errorMessage = "未识别到文字。请保证号码区域对焦清晰、光线充足且避免反光。"
                return
            }
            let parsed = TicketOCRParser.analyze(lines: lines, kind: kind)
            analysis = parsed
            issueNumber = parsed.issueNumber
            editableEntries = parsed.entries.enumerated().map { index, entry in
                EditableScannedEntry(
                    sequence: index + 1,
                    frontNumbersText: numberText(entry.frontNumbers),
                    backNumbersText: numberText(entry.backNumbers)
                )
            }
            if editableEntries.isEmpty {
                editableEntries = [EditableScannedEntry(sequence: 1)]
                errorMessage = "未能可靠识别完整号码，请手动补全后再应用。"
            }
        } catch {
            errorMessage = "文字识别失败：\(error.localizedDescription)"
        }
    }

    private func recognizeLines(in image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [RecognizedLine] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { observation -> RecognizedLine? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return RecognizedLine(text: candidate.string, confidence: candidate.confidence)
                    } ?? []
                continuation.resume(returning: lines)
            }
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.customWords = ["双色球", "超级大乐透", "期", "追加"]

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func applyDraft(confidence: Float) {
        guard !issueNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "请确认开奖期号。"
            return
        }

        var entries: [TicketNumberDraft] = []
        for entry in editableEntries {
            let front = TicketOCRParser.numbers(from: entry.frontNumbersText)
            let back = TicketOCRParser.numbers(from: entry.backNumbersText)
            guard TicketOCRParser.isValid(front, in: kind.frontRange, expectedCount: kind.frontCount) else {
                validationMessage = "请确认第 \(entry.sequence) 注前区号码的数量、范围和是否重复。"
                return
            }
            guard TicketOCRParser.isValid(back, in: kind.backRange, expectedCount: kind.backCount) else {
                validationMessage = "请确认第 \(entry.sequence) 注后区号码的数量、范围和是否重复。"
                return
            }
            entries.append(TicketNumberDraft(frontNumbers: front.sorted(), backNumbers: back.sorted()))
        }

        onApply(
            TicketScanDraft(
                issueNumber: LotteryIssue.normalize(issueNumber, for: kind),
                entries: entries,
                confidence: confidence
            )
        )
        dismiss()
    }

    private func numberText(_ values: [Int]) -> String {
        values.map { String(format: "%02d", $0) }.joined(separator: " ")
    }
}

private struct EditableScannedEntry: Identifiable {
    let id = UUID()
    let sequence: Int
    var frontNumbersText = ""
    var backNumbersText = ""
}

private enum TicketOCRParser {
    static func analyze(lines: [RecognizedLine], kind: LotteryKind) -> TicketScanAnalysis {
        let issueNumber = lines
            .flatMap { numericTokens(from: $0.text) }
            .first(where: { $0.count == (kind == .doubleColorBall ? 7 : 5) }) ?? ""

        var candidates = lines.flatMap { validCombinations(in: numbers(from: $0.text), kind: kind) }
        if candidates.isEmpty {
            candidates = validCombinations(in: lines.flatMap { numbers(from: $0.text) }, kind: kind)
        }

        var seen = Set<String>()
        let entries = candidates.compactMap { front, back -> TicketNumberDraft? in
            let key = "\(LotteryDraw.encode(front))|\(LotteryDraw.encode(back))"
            guard seen.insert(key).inserted else { return nil }
            return TicketNumberDraft(frontNumbers: front, backNumbers: back)
        }

        return TicketScanAnalysis(
            lines: lines,
            issueNumber: LotteryIssue.normalize(issueNumber, for: kind),
            entries: Array(entries.prefix(20))
        )
    }

    static func numbers(from text: String) -> [Int] {
        numericTokens(from: text)
            .filter { $0.count <= 2 }
            .compactMap(Int.init)
    }

    static func isValid(_ values: [Int], in range: ClosedRange<Int>, expectedCount: Int) -> Bool {
        values.count == expectedCount
            && Set(values).count == expectedCount
            && values.allSatisfy(range.contains)
    }

    private static func validCombinations(in values: [Int], kind: LotteryKind) -> [([Int], [Int])] {
        let count = kind.frontCount + kind.backCount
        guard values.count >= count else { return [] }
        return (0...(values.count - count)).compactMap { index in
            let candidate = Array(values[index..<(index + count)])
            let front = Array(candidate.prefix(kind.frontCount))
            let back = Array(candidate.suffix(kind.backCount))
            guard isValid(front, in: kind.frontRange, expectedCount: kind.frontCount),
                  isValid(back, in: kind.backRange, expectedCount: kind.backCount),
                  front == front.sorted(),
                  back == back.sorted() else {
                return nil
            }
            return (front, back)
        }
    }

    private static func numericTokens(from text: String) -> [String] {
        text.split(whereSeparator: { !$0.isNumber }).map(String.init)
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
