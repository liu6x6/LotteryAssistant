import AVFoundation
import SwiftUI
import Vision
import VisionKit

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasCameraAccess: Bool?
    @State private var selectedSymbologyID = BarcodeSymbologyOption.all.id
    @State private var scanResults: [BarcodeScanResult] = []
    @State private var scannerError: String?

    private var selectedOption: BarcodeSymbologyOption {
        BarcodeSymbologyOption.options.first(where: { $0.id == selectedSymbologyID }) ?? .all
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if hasCameraAccess == true,
                   DataScannerViewController.isSupported,
                   DataScannerViewController.isAvailable {
                    LiveBarcodeScanner(
                            symbologies: selectedOption.symbologies,
                            scanResults: $scanResults,
                        scannerError: $scannerError
                    )
                        .id(selectedSymbologyID)
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .center) {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                                .stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                                .frame(width: 320, height: 120)
                                .shadow(radius: 4)
                                .allowsHitTesting(false)
                        }
                } else if hasCameraAccess == false {
                    ContentUnavailableView(
                        "需要相机权限",
                        systemImage: "camera.fill",
                        description: Text("请在系统设置中允许彩票助手访问相机后重试。")
                    )
                } else if hasCameraAccess == nil {
                    ProgressView("正在检查相机权限…")
                } else {
                    ContentUnavailableView(
                        "无法使用条码扫描",
                        systemImage: "barcode.viewfinder",
                        description: Text("请在支持相机扫描的 iPhone 或 iPad 上测试。")
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                resultPanel
            }
            .navigationTitle("条形码扫描")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                await requestCameraAccess()
            }
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("扫描类型")
                    .font(.headline)
                Spacer()
                Picker("扫描类型", selection: $selectedSymbologyID) {
                    ForEach(BarcodeSymbologyOption.options) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Text("请让条形码横向占满扫描框，并避免反光。将尝试识别 Code 128 及其他常见一维条码。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Color.secondaryText)

            if !scanResults.isEmpty {
                HStack {
                    Text("扫描结果（\(scanResults.count)）")
                        .font(.headline)
                    Spacer()
                    Button("清空") {
                        scanResults.removeAll()
                    }
                    .font(.caption.weight(.semibold))
                }

                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.xs) {
                        ForEach(scanResults) { result in
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                HStack {
                                    Text(result.symbology)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Color.primary)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = result.value
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .accessibilityLabel("复制该条码内容")
                                }
                                Text(result.value)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(AppTheme.Spacing.sm)
                            .background(AppTheme.Color.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        }
                    }
                }
                .frame(maxHeight: 220)
            } else if let scannerError {
                Label(scannerError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.error)
            } else {
                Label("等待识别一维条形码", systemImage: "barcode")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(.bar)
    }

    private func requestCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraAccess = true
        case .notDetermined:
            hasCameraAccess = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            hasCameraAccess = false
        @unknown default:
            hasCameraAccess = false
        }
    }
}

private struct BarcodeScanResult: Identifiable, Equatable {
    let id = UUID()
    let symbology: String
    let value: String
}

private struct BarcodeSymbologyOption: Identifiable {
    let id: String
    let name: String
    let symbologies: [VNBarcodeSymbology]

    static let all = BarcodeSymbologyOption(id: "all", name: "全部类型（自动）", symbologies: [])

    static let options: [BarcodeSymbologyOption] = [
        all,
        .init(id: "code128", name: "Code 128", symbologies: [.code128]),
        .init(id: "code39", name: "Code 39", symbologies: [.code39]),
        .init(id: "code39-checksum", name: "Code 39 Checksum", symbologies: [.code39Checksum]),
        .init(id: "code39-full-ascii", name: "Code 39 Full ASCII", symbologies: [.code39FullASCII]),
        .init(id: "code39-full-ascii-checksum", name: "Code 39 Full ASCII Checksum", symbologies: [.code39FullASCIIChecksum]),
        .init(id: "code93", name: "Code 93", symbologies: [.code93]),
        .init(id: "code93i", name: "Code 93i", symbologies: [.code93i]),
        .init(id: "i2of5", name: "Interleaved 2 of 5", symbologies: [.i2of5]),
        .init(id: "i2of5-checksum", name: "Interleaved 2 of 5 Checksum", symbologies: [.i2of5Checksum]),
        .init(id: "itf14", name: "ITF-14", symbologies: [.itf14]),
        .init(id: "codabar", name: "Codabar", symbologies: [.codabar]),
        .init(id: "msi-plessey", name: "MSI Plessey", symbologies: [.msiPlessey]),
        .init(id: "ean8", name: "EAN-8", symbologies: [.ean8]),
        .init(id: "ean13", name: "EAN-13", symbologies: [.ean13]),
        .init(id: "upce", name: "UPC-E", symbologies: [.upce]),
        .init(id: "gs1-databar", name: "GS1 DataBar", symbologies: [.gs1DataBar]),
        .init(id: "gs1-databar-expanded", name: "GS1 DataBar Expanded", symbologies: [.gs1DataBarExpanded]),
        .init(id: "gs1-databar-limited", name: "GS1 DataBar Limited", symbologies: [.gs1DataBarLimited]),
        .init(id: "pdf417", name: "PDF417", symbologies: [.pdf417]),
        .init(id: "micro-pdf417", name: "MicroPDF417", symbologies: [.microPDF417]),
        .init(id: "data-matrix", name: "Data Matrix", symbologies: [.dataMatrix]),
        .init(id: "aztec", name: "Aztec", symbologies: [.aztec]),
        .init(id: "qr", name: "QR Code", symbologies: [.qr]),
        .init(id: "micro-qr", name: "Micro QR", symbologies: [.microQR])
    ]
}

private struct LiveBarcodeScanner: UIViewControllerRepresentable {
    let symbologies: [VNBarcodeSymbology]
    @Binding var scanResults: [BarcodeScanResult]
    @Binding var scannerError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies)],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard !uiViewController.isScanning else { return }
        do {
            try uiViewController.startScanning()
            scannerError = nil
        } catch {
            scannerError = "无法启动条码扫描：\(error.localizedDescription)"
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let parent: LiveBarcodeScanner

        init(parent: LiveBarcodeScanner) {
            self.parent = parent
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            updateResult(from: addedItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            updateResult(from: updatedItems)
        }

        private func updateResult(from items: [RecognizedItem]) {
            for item in items {
                guard case .barcode(let barcode) = item,
                      let value = barcode.payloadStringValue,
                      !value.isEmpty else {
                    continue
                }
                let symbology = Self.displayName(for: barcode.observation.symbology)
                guard !parent.scanResults.contains(where: {
                    $0.symbology == symbology && $0.value == value
                }) else {
                    continue
                }
                parent.scanResults.append(BarcodeScanResult(symbology: symbology, value: value))
                parent.scannerError = nil
                print("[BarcodeScanner] type=\(symbology), value=\(value)")
            }
        }

        private static func displayName(for symbology: VNBarcodeSymbology) -> String {
            switch symbology {
            case .code128: "Code 128"
            case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: "Code 39"
            case .code93, .code93i: "Code 93"
            case .i2of5, .i2of5Checksum: "Interleaved 2 of 5"
            case .itf14: "ITF-14"
            case .codabar: "Codabar"
            case .ean8: "EAN-8"
            case .ean13: "EAN-13"
            case .upce: "UPC-E"
            case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: "GS1 DataBar"
            case .pdf417: "PDF417"
            case .microPDF417: "MicroPDF417"
            case .dataMatrix: "Data Matrix"
            case .aztec: "Aztec"
            case .qr: "QR Code"
            case .microQR: "Micro QR"
            case .msiPlessey: "MSI Plessey"
            default: symbology.rawValue
            }
        }
    }
}
