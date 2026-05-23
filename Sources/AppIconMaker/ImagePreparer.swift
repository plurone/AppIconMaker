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

public struct ImagePreparationOptions: Equatable, Sendable {
    public static let contentScaleRange = 0.50...1.50
    public static let offsetRange = -0.35...0.35

    public var mode: ImagePreparationMode
    public var contentScale: Double
    public var horizontalOffset: Double
    public var verticalOffset: Double

    public init(
        mode: ImagePreparationMode = .centerCrop,
        contentScale: Double = 1.0,
        horizontalOffset: Double = 0.0,
        verticalOffset: Double = 0.0
    ) {
        self.mode = mode
        self.contentScale = contentScale
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
    }

    var normalized: ImagePreparationOptions {
        ImagePreparationOptions(
            mode: mode,
            contentScale: contentScale.clamped(to: Self.contentScaleRange),
            horizontalOffset: horizontalOffset.clamped(to: Self.offsetRange),
            verticalOffset: verticalOffset.clamped(to: Self.offsetRange)
        )
    }

    public var displayDescription: String {
        let normalized = normalized
        let percentage = Int((normalized.contentScale * 100).rounded())
        let horizontal = Int((normalized.horizontalOffset * 100).rounded())
        let vertical = Int((normalized.verticalOffset * 100).rounded())

        guard percentage != 100 || horizontal != 0 || vertical != 0 else {
            return normalized.mode.displayName
        }

        return "\(normalized.mode.displayName) · \(percentage)% · 偏移 \(horizontal), \(vertical)"
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
    public let options: ImagePreparationOptions

    public var mode: ImagePreparationMode {
        options.mode
    }
}

public enum ImagePreparer {
    public static let outputPixelSize = 1024

    public static func prepare(_ sourceImage: CGImage, mode: ImagePreparationMode) throws -> PreparedImage {
        try prepare(sourceImage, options: .init(mode: mode))
    }

    public static func prepare(_ sourceImage: CGImage, options: ImagePreparationOptions) throws -> PreparedImage {
        let pixelSize = outputPixelSize
        let options = options.normalized
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
        context.draw(sourceImage, in: drawRect(for: sourceImage, options: options, pixelSize: pixelSize))

        guard let image = context.makeImage() else {
            throw ImagePreparationError.cannotCreateImage
        }

        return PreparedImage(
            cgImage: image,
            previewImage: NSImage(cgImage: image, size: NSSize(width: pixelSize, height: pixelSize)),
            width: pixelSize,
            height: pixelSize,
            options: options
        )
    }

    static func drawRect(for sourceImage: CGImage, mode: ImagePreparationMode, pixelSize: Int) -> CGRect {
        drawRect(for: sourceImage, options: .init(mode: mode), pixelSize: pixelSize)
    }

    static func drawRect(for sourceImage: CGImage, options: ImagePreparationOptions, pixelSize: Int) -> CGRect {
        let sourceWidth = CGFloat(sourceImage.width)
        let sourceHeight = CGFloat(sourceImage.height)
        let canvasSize = CGFloat(pixelSize)
        let options = options.normalized

        let baseScale: CGFloat
        switch options.mode {
        case .centerCrop:
            baseScale = max(canvasSize / sourceWidth, canvasSize / sourceHeight)
        case .transparentPadding:
            baseScale = min(canvasSize / sourceWidth, canvasSize / sourceHeight)
        }

        let scale = baseScale * CGFloat(options.contentScale)
        let width = sourceWidth * scale
        let height = sourceHeight * scale
        return CGRect(
            x: (canvasSize - width) / 2 + CGFloat(options.horizontalOffset) * canvasSize,
            y: (canvasSize - height) / 2 + CGFloat(options.verticalOffset) * canvasSize,
            width: width,
            height: height
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
