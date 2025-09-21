import Foundation
import UIKit

enum PDFBuilderError: Error {
    case emptyInput
}

struct PDFDocumentMetadata {
    var title: String?
    var author: String?
    var subject: String?
    var keywords: [String]?
}

enum PDFBuilder {
    static func makePDF(from images: [UIImage], metadata: PDFDocumentMetadata? = nil) throws -> Data {
        guard !images.isEmpty else { throw PDFBuilderError.emptyInput }

        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        if let metadata = metadata {
            var info: [String: Any] = [:]
            if let title = metadata.title { info[kCGPDFContextTitle as String] = title }
            if let author = metadata.author { info[kCGPDFContextAuthor as String] = author }
            if let subject = metadata.subject { info[kCGPDFContextSubject as String] = subject }
            if let keywords = metadata.keywords { info[kCGPDFContextKeywords as String] = keywords.joined(separator: ", ") }
            format.documentInfo = info
        }

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        return renderer.pdfData { context in
            for image in images {
                context.beginPage()
                let target = aspectFitRect(for: image, in: pageBounds.insetBy(dx: 18, dy: 18))
                image.draw(in: target)
            }
        }
    }

    private static func aspectFitRect(for image: UIImage, in rect: CGRect) -> CGRect {
        let imageSize = image.size
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: rect.midX - fittedSize.width / 2,
            y: rect.midY - fittedSize.height / 2
        )
        return CGRect(origin: origin, size: fittedSize)
    }
}

