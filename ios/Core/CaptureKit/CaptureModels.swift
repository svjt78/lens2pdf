import Foundation
import UIKit

struct CapturePage: Identifiable {
    let id = UUID()
    let index: Int
    let image: UIImage
    let quality: CaptureQuality
}

struct CaptureQuality {
    let warnings: [CaptureQualityWarning]
    var hasWarnings: Bool { !warnings.isEmpty }
}

enum CaptureQualityWarning: String, CaseIterable, Identifiable {
    case lowResolution
    case lowLight
    case glare

    var id: String { rawValue }

    var message: String {
        switch self {
        case .lowResolution:
            return "Image may be blurry or too small; retake for better clarity."
        case .lowLight:
            return "Lighting is dim; consider retaking with better lighting."
        case .glare:
            return "Glare detected; adjust angle to reduce reflections."
        }
    }
}

struct CaptureResult {
    let pages: [CapturePage]
}

enum CaptureError: Error, LocalizedError {
    case visionKitUnavailable
    case cancelled
    case emptyScan

    var errorDescription: String? {
        switch self {
        case .visionKitUnavailable:
            return "VisionKit is not available on this device."
        case .cancelled:
            return "Capture was cancelled."
        case .emptyScan:
            return "No pages were captured."
        }
    }
}

