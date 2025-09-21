import Foundation
import SwiftUI
import UIKit

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var capturedPages: [CapturePage] = []
    @Published var processingState: ProcessingState = .idle
    @Published var warningsByPage: [UUID: [CaptureQualityWarning]] = [:]
    @Published var savedDocument: ScanDocument?
    @Published var pdfData: Data?
    @Published var documentTitle: String = ""

    var hasWarnings: Bool { warningsByPage.values.contains { !$0.isEmpty } }

    private let settingsStore = SettingsStore.shared
    private let scanStore = ScanStore.shared

    enum ProcessingState: Equatable {
        case idle
        case processing(String)
        case error(String)
        case completed
    }

    func reset() {
        capturedPages = []
        warningsByPage = [:]
        savedDocument = nil
        pdfData = nil
        processingState = .idle
        documentTitle = ""
    }

    func applyCapture(result: CaptureResult) {
        capturedPages = result.pages.sorted { $0.index < $1.index }
        warningsByPage = Dictionary(uniqueKeysWithValues: capturedPages.map { ($0.id, $0.quality.warnings) })
        if documentTitle.isEmpty {
            documentTitle = defaultTitle()
        }
    }

    func removePage(_ page: CapturePage) {
        capturedPages.removeAll { $0.id == page.id }
        warningsByPage[page.id] = nil
        if capturedPages.isEmpty {
            processingState = .idle
        }
    }

    func processAndSave() {
        guard !capturedPages.isEmpty else { return }
        processingState = .processing("Optimizing images…")
        let images = capturedPages.map { $0.image }
        let settings = settingsStore.settings
        let fxSettings = ImageFXSettings(quality: settings.jpegQuality, mode: settings.defaultColorMode)

        Task {
            do {
                let processedImages = try await processImages(images, settings: fxSettings)
                await MainActor.run { [weak self] in
                    self?.processingState = .processing("Rendering PDF…")
                }
                let metadata = PDFDocumentMetadata(title: documentTitle, author: "Receipt Scanner", subject: "VisionKit capture", keywords: nil)
                let pdf = try PDFBuilder.makePDF(from: processedImages, metadata: metadata)
                let stored = try scanStore.addDocument(title: documentTitle, processedImages: processedImages, pdfData: pdf, imageQuality: settings.jpegQuality)
                await MainActor.run { [weak self] in
                    self?.savedDocument = stored
                    self?.pdfData = pdf
                    self?.processingState = .completed
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.processingState = .error(error.localizedDescription)
                }
            }
        }
    }

    private func processImages(_ images: [UIImage], settings: ImageFXSettings) async throws -> [UIImage] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let processed = try ImageFX.process(images: images, settings: settings)
                    continuation.resume(returning: processed)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "Scan_\(formatter.string(from: Date()))"
    }
}

