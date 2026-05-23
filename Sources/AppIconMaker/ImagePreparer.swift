import AppKit
import CoreGraphics
import Foundation

public enum ImagePreparationMode: String, CaseIterable, Identifiable, Sendable {
    case centerCrop
    case transparentPadding

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .centerCrop:
            "居中裁剪"
        case .transparentPadding:
            "透明填充"
        }
    }

    public var detail: String {
        switch self {
        case .centerCrop:
            "铺满 1024，居中裁掉多余区域"
        case .transparentPadding:
            "完整保留，空白区域透明"
        }
    }
}

public enum ImagePreparationError: LocalizedError {
    case cannotCreateContext
    case cannotCreateImage

    public var errorDescription: String? {
        switch self {
        case .cannotCreateContext:
            "无法创建 1024x1024 预处理画布。"
        case .cannotCreateImage:
            "无法生成 1024x1024 预处理图片。"
        }
    }
}

public struct PreparedImage {
    public let cgImage: CGImage
    public let previewImage: NSImage
    public let width: Int
    public let height: Int
    public let mode: ImagePreparationMode
}

public enum ImagePreparer {
    public static let outputPixelSize = 1024

    public static func prepare(_ sourceImage: CGImage, mode: ImagePreparationMode) throws -> PreparedImage {
        let pixelSize = outputPixelSize
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw ImagePreparationError.cannotCreateContext
        }

        context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        context.interpolationQuality = .high
        context.draw(sourceImage, in: drawRect(for: sourceImage, mode: mode, pixelSize: pixelSize))

        guard let image = context.makeImage() else {
            throw ImagePreparationError.cannotCreateImage
        }

        return PreparedImage(
            cgImage: image,
            previewImage: NSImage(cgImage: image, size: NSSize(width: pixelSize, height: pixelSize)),
            width: pixelSize,
            height: pixelSize,
            mode: mode
        )
    }

    static func drawRect(for sourceImage: CGImage, mode: ImagePreparationMode, pixelSize: Int) -> CGRect {
        let sourceWidth = CGFloat(sourceImage.width)
        let sourceHeight = CGFloat(sourceImage.height)
        let canvasSize = CGFloat(pixelSize)

        let scale: CGFloat
        switch mode {
        case .centerCrop:
            scale = max(canvasSize / sourceWidth, canvasSize / sourceHeight)
        case .transparentPadding:
            scale = min(canvasSize / sourceWidth, canvasSize / sourceHeight)
        }

        let width = sourceWidth * scale
        let height = sourceHeight * scale
        return CGRect(
            x: (canvasSize - width) / 2,
            y: (canvasSize - height) / 2,
            width: width,
            height: height
        )
    }
}
