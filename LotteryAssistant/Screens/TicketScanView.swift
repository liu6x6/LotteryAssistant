import PhotosUI
import SwiftUI
@preconcurrency import Vision

struct TicketScanDraft {
    let issueNumber: String
    let frontNumbers: [Int]
    let backNumbers: [Int]
}

struct TicketScanView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LotteryKind
    let onApply: (TicketScanDraft) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var recognizedText = ""
    @State private var isRecognizing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.Color.primary)
                        Text("从票据照片识别号码")
                            .font(.title2.bold())
                        Text("识别结果可能有误。请在返回录入页后逐项确认号码、期号和倍数。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Color.secondaryText)
                    }
                    .appCard()

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("选择票据照片", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if isRecognizing {
                        HStack {
                            ProgressView()
                            Text("正在识别文字…")
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                    }

                    if !recognizedText.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("识别文本")
                                .font(.headline)
                            Text(recognizedText)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("应用可识别号码") {
                                onApply(makeDraft())
                                dismiss()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .appCard()
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
                Task { await recognizeSelectedImage() }
            }
        }
    }

    @MainActor
    private func recognizeSelectedImage() async {
        guard let selectedItem else { return }
        isRecognizing = true
        errorMessage = nil
        defer { isRecognizing = false }

        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                errorMessage = "无法读取这张图片，请换一张清晰的票据照片。"
                return
            }
            recognizedText = try await recognizeText(in: cgImage)
            if recognizedText.isEmpty {
                errorMessage = "未识别到文字，请使用光线充足、号码清晰的票据照片。"
            }
        } catch {
            errorMessage = "识别失败：\(error.localizedDescription)"
        }
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeDraft() -> TicketScanDraft {
        let numericTokens = recognizedText
            .split(whereSeparator: { !$0.isNumber })
            .map(String.init)
        let values = numericTokens
            .filter { $0.count <= 2 }
            .compactMap(Int.init)
        let front = values.filter(kind.frontRange.contains).prefix(kind.frontCount)
        let remaining = values.dropFirst(front.count)
        let back = remaining.filter(kind.backRange.contains).prefix(kind.backCount)
        let issue = numericTokens.first(where: { $0.count == 7 }) ?? ""
        return TicketScanDraft(issueNumber: issue, frontNumbers: Array(front).sorted(), backNumbers: Array(back).sorted())
    }
}
