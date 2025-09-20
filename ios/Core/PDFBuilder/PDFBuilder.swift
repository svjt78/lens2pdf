import Foundation

public enum PDFBuilderError: Error {
    case unsupported
}

public struct PDFBuildOptions {
    public var includeTextLayer: Bool
    public init(includeTextLayer: Bool = true) { self.includeTextLayer = includeTextLayer }
}

public enum PDFProfile {
    case standard
    case compact // targets 2–3 MB for multi-page receipts with ImageFX compact
}

public enum PDFBuilder {
    // images: array of JPEG/PNG data per page
    // ocrPages: array of OCR blocks per page (normalized 0..1 bounding boxes)
    public static func buildPDF(images: [Data], ocrPages: [[OCRBlock]], options: PDFBuildOptions = .init()) throws -> Data {
        #if canImport(UIKit) && canImport(PDFKit)
        import UIKit
        import PDFKit

        let pdf = PDFDocument()
        for (idx, data) in images.enumerated() {
            guard let ui = UIImage(data: data) else { continue }
            let page = PDFPage(image: ui)
            if options.includeTextLayer, idx < ocrPages.count, let pageRef = page?.pageRef {
                // Draw text annotations in an invisible layer aligned to image
                // For simplicity, add PDF annotations with zero alpha (selectable, not visible)
                let blocks = ocrPages[idx]
                for block in blocks {
                    let rect = CGRect(x: block.boundingBox.minX * ui.size.width,
                                      y: (1.0 - block.boundingBox.maxY) * ui.size.height,
                                      width: block.boundingBox.width * ui.size.width,
                                      height: block.boundingBox.height * ui.size.height)
                    let annot = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
                    annot.contents = block.text
                    annot.font = .systemFont(ofSize: 10)
                    annot.color = .clear
                    annot.fontColor = .clear
                    page?.addAnnotation(annot)
                }
            }
            if let page = page { pdf.insert(page, at: pdf.pageCount) }
        }
        guard let data = pdf.dataRepresentation() else { throw PDFBuilderError.unsupported }
        return data
        #else
        // Non-iOS environment: not supported in this repo context
        throw PDFBuilderError.unsupported
        #endif
    }
}

