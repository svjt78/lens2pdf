import Foundation

public enum ImageFXError: Error {
    case processingUnavailable
}

public struct ImageFXProfile {
    public var dpi: Int
    public var jpegQuality: Float // 0..1
    public var binarize: Bool
    public init(dpi: Int = 200, jpegQuality: Float = 0.7, binarize: Bool = true) {
        self.dpi = dpi
        self.jpegQuality = jpegQuality
        self.binarize = binarize
    }
    public static let compactReceipt = ImageFXProfile(dpi: 200, jpegQuality: 0.65, binarize: true)
}

public enum ImageFX {
    // Returns transformed image data (JPEG) per page according to profile.
    public static func processForReceiptCompact(images: [Data], profile: ImageFXProfile = .compactReceipt) throws -> [Data] {
        #if canImport(UIKit)
        import UIKit
        return try images.map { data in
            guard let ui = UIImage(data: data) else { return data }
            // NOTE: Real implementation would apply perspective correction, denoise, contrast, binarize, and downscale.
            // Here we only downscale and re-encode for portability in this repo context.
            let maxDim: CGFloat = 2000
            let scale = min(1.0, maxDim / max(ui.size.width, ui.size.height))
            let size = CGSize(width: ui.size.width * scale, height: ui.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            ui.draw(in: CGRect(origin: .zero, size: size))
            let resized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let q = CGFloat(profile.jpegQuality)
            return resized?.jpegData(compressionQuality: q) ?? data
        }
        #else
        // Non-iOS placeholder: return original data
        return images
        #endif
    }
}

