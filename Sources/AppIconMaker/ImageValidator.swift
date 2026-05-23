import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageValidationError: LocalizedError, Equatable {
    case notPNG
    case unreadable
    case missingPixelSize
    case invalidPixelSize(width: Int, height: Int)

    public var errorDescription: String? {
        switch self {
        case .notPNG:
            "请选择 PNG 图片。"
        case .unreadable:
            "无法读取这张图片。"
        case .missingPixelSize:
            "无法识别图片像素尺寸。"
        case let .invalidPixelSize(width, height):
            "图片必须是 1024x1024 像素，当前是 \(width)x\(height)。"
        }
    }
}

public struct ValidatedImage {
    public let url: URL
    public let cgImage: CGImage
    public let normalizedCGImage: CGImage
    public let previewImage: NSImage
    public let width: Int
    public let height: Int
    public let normalizationInfo: ImageNormalizationInfo
}

public enum ImageValidator {
    public static let requiredPixelSize = 1024

    public static func loadPNG(at url: URL) throws -> ValidatedImage {
        guard isPNG(url: url) else {
            throw ImageValidationError.notPNG
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source),
              UTType(type as String)?.conforms(to: .png) == true
        else {
            throw ImageValidationError.unreadable
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageValidationError.unreadable
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            throw ImageValidationError.missingPixelSize
        }

        let normalized = try ImageNormalizer.normalize(cgImage)

        return ValidatedImage(
            url: url,
            cgImage: cgImage,
            normalizedCGImage: normalized.0,
            previewImage: NSImage(cgImage: normalized.0, size: NSSize(width: width, height: height)),
            width: width,
            height: height,
            normalizationInfo: normalized.1
        )
    }

    public static func validatePNG(at url: URL) throws -> ValidatedImage {
        let image = try loadPNG(at: url)

        guard image.width == requiredPixelSize, image.height == requiredPixelSize else {
            throw ImageValidationError.invalidPixelSize(width: image.width, height: image.height)
        }

        return image
    }

    private static func isPNG(url: URL) -> Bool {
        if url.pathExtension.lowercased() == "png" {
            return true
        }

        guard let resourceType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }

        return resourceType.conforms(to: .png)
    }
}
