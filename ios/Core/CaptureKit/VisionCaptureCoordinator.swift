import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(VisionKit)
import VisionKit
#endif

final class VisionCaptureCoordinator: NSObject {
    private var completion: ((Result<CaptureResult, Error>) -> Void)?

    func makeViewController(completion: @escaping (Result<CaptureResult, Error>) -> Void) -> UIViewController {
        self.completion = completion
        #if canImport(VisionKit)
        guard VNDocumentCameraViewController.isSupported else {
            completion(.failure(CaptureError.visionKitUnavailable))
            return UIViewController()
        }
        let controller = VNDocumentCameraViewController()
        controller.delegate = self
        return controller
        #else
        completion(.failure(CaptureError.visionKitUnavailable))
        return UIViewController()
        #endif
    }
}

#if canImport(VisionKit)
extension VisionCaptureCoordinator: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        defer { completion = nil }
        guard scan.pageCount > 0 else {
            completion?(.failure(CaptureError.emptyScan))
            return
        }
        var pages: [CapturePage] = []
        for index in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: index)
            let quality = CaptureQualityAnalyzer.evaluate(image: image)
            pages.append(CapturePage(index: index, image: image, quality: quality))
        }
        completion?(.success(CaptureResult(pages: pages)))
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        defer { completion = nil }
        completion?(.failure(CaptureError.cancelled))
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        defer { completion = nil }
        completion?(.failure(error))
    }
}
#endif

private enum CaptureQualityAnalyzer {
    static func evaluate(image: UIImage) -> CaptureQuality {
        var warnings: [CaptureQualityWarning] = []

        let minDimension = min(image.size.width, image.size.height)
        if minDimension < 1200 {
            warnings.append(.lowResolution)
        }

        if let cgImage = image.cgImage {
            let brightness = averageLuminance(of: cgImage)
            if brightness < 0.2 {
                warnings.append(.lowLight)
            }
            if brightness > 0.85 {
                warnings.append(.glare)
            }
        }

        return CaptureQuality(warnings: warnings)
    }

    private static func averageLuminance(of cgImage: CGImage) -> CGFloat {
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = extent
        guard let output = filter.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(output,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

