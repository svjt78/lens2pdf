import Foundation

// Protocol-based design to allow testing without Vision framework.
public protocol OCRService {
    func recognizeText(from images: [Data]) async throws -> [[OCRBlock]]
}

#if canImport(UIKit) && canImport(Vision)
import UIKit
import Vision

public final class VisionOCRService: OCRService {
    public init() {}
    public func recognizeText(from images: [Data]) async throws -> [[OCRBlock]] {
        var results: [[OCRBlock]] = []
        for data in images {
            guard let ui = UIImage(data: data)?.cgImage else { results.append([]); continue }
            let req = VNRecognizeTextRequest()
            req.recognitionLanguages = ["en-US"]
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: ui, options: [:])
            try handler.perform([req])
            let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
            let pageBlocks: [OCRBlock] = obs.compactMap { obs in
                guard let top = obs.topCandidates(1).first else { return nil }
                // Convert bounding box from normalized to pixel-independent CGRect (0..1 space)
                return OCRBlock(text: top.string, boundingBox: obs.boundingBox)
            }
            results.append(pageBlocks)
        }
        return results
    }
}
#else
// Fallback stub for non-iOS environments so the package can compile or be analyzed.
public final class VisionOCRService: OCRService {
    public init() {}
    public func recognizeText(from images: [Data]) async throws -> [[OCRBlock]] { return images.map { _ in [] } }
}
#endif

