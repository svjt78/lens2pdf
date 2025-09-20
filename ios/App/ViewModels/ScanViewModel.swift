import Foundation
import SwiftUI

final class ScanViewModel: ObservableObject {
    @Published var selectedImages: [Data] = []
    @Published var isProcessing: Bool = false
    @Published var progressText: String = ""

    @Published var extractedVendor: String = ""
    @Published var extractedDate: String = ""
    @Published var extractedTotal: String = ""

    @Published var pdfData: Data?
    @Published var suggestedFileName: String = "Receipt.pdf"

    func reset() {
        selectedImages = []
        isProcessing = false
        progressText = ""
        extractedVendor = ""
        extractedDate = ""
        extractedTotal = ""
        pdfData = nil
        suggestedFileName = "Receipt.pdf"
    }

    @MainActor
    func runPipeline() async {
        guard !selectedImages.isEmpty else { return }
        isProcessing = true
        progressText = "Optimizing images…"

        do {
            // 1) ImageFX compact processing
            let processed = try ImageFX.processForReceiptCompact(images: selectedImages)

            // 2) OCR
            progressText = "Recognizing text…"
            let ocr = VisionOCRService()
            let ocrPages = try await ocr.recognizeText(from: processed)

            // 3) Extraction
            progressText = "Extracting receipt details…"
            let fullText = ocrPages.flatMap { $0 }.map { $0.text }.joined(separator: "\n")
            let extraction = ReceiptIntel.extract(from: fullText)
            suggestedFileName = ReceiptIntel.suggestFileName(from: extraction)

            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            extractedVendor = extraction.vendor ?? ""
            extractedDate = extraction.date.map { df.string(from: $0) } ?? ""
            if let t = extraction.total { extractedTotal = "$" + NSDecimalNumber(decimal: t).stringValue } else { extractedTotal = "" }

            // 4) PDF with text layer
            progressText = "Building PDF…"
            let pdf = try PDFBuilder.buildPDF(images: processed, ocrPages: ocrPages)
            self.pdfData = pdf
            progressText = ""
        } catch {
            progressText = "Error: \(error.localizedDescription)"
        }
        isProcessing = false
    }
}

