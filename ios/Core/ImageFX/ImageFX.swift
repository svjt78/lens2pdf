import Foundation
import UIKit
import CoreImage

enum ColorMode: String, Codable, CaseIterable, Identifiable {
    case color
    case grayscale
    case monochrome

    var id: String { rawValue }
}

struct ImageFXSettings {
    let quality: Int
    let mode: ColorMode

    static let `default` = ImageFXSettings(quality: 90, mode: .color)
}

enum ImageFXError: Error {
    case contextFailure
    case imageConversion
}

enum ImageFX {
    static func process(images: [UIImage], settings: ImageFXSettings) throws -> [UIImage] {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return try images.enumerated().map { index, image in
            guard var ciImage = CIImage(image: image) else { throw ImageFXError.imageConversion }
            ciImage = ciImage.oriented(forExifOrientation: Int32(image.imageOrientation.exifOrientation))
            ciImage = ciImage.applyingFilter("CINoiseReduction", parameters: [kCIInputNoiseLevelKey: 0.02, kCIInputSharpnessKey: 0.4])
            ciImage = ciImage.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.25])

            switch settings.mode {
            case .color:
                break
            case .grayscale:
                ciImage = ciImage.applyingFilter("CIPhotoEffectMono")
            case .monochrome:
                ciImage = ciImage.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.1])
            }

            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                throw ImageFXError.contextFailure
            }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
        }
    }
}

private extension UIImage.Orientation {
    var exifOrientation: UIImage.Orientation.RawValue {
        switch self {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}

