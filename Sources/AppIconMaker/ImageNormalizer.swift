import AppKit
import CoreGraphics
import CoreImage
import Foundation

public struct ImageNormalizationInfo: Equatable {
    public let sourceColorSpaceName: String
    public let outputColorSpaceName: String
    public let assumedSRGB: Bool
    public let convertedToSRGB: Bool
    public let hasAlphaChannel: Bool
    public let hasTransparentPixels: Bool

    public var colorDescription: String {
        if assumedSRGB {
            return "未嵌入色彩配置，已按 sRGB 处理"
        }

        if convertedToSRGB {
            return "\(sourceColorSpaceName) -> \(outputColorSpaceName)"
        }

        return outputColorSpaceName
    }

    public var alphaDescription: String {
        if hasTransparentPixels {
            return "检测到透明像素"
        }

        if hasAlphaChannel {
            return "包含 Alpha 通道，但像素不透明"
        }

        return "不含 Alpha 通道"
    }
}

public enum ImageNormalizer {
    public static let outputColorSpaceName = "sRGB"

    private static var outputColorSpace: CGColorSpace {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    public static func normalize(_ image: CGImage) throws -> (CGImage, ImageNormalizationInfo) {
        let sourceColorSpace = image.colorSpace
        let sourceName = colorSpaceName(sourceColorSpace)
        let assumedSRGB = sourceColorSpace == nil
        let outputColorSpace = outputColorSpace
        let inputColorSpace = sourceColorSpace ?? outputColorSpace
        let normalized = try renderSRGB(image, inputColorSpace: inputColorSpace, outputColorSpace: outputColorSpace)
        let hasAlphaChannel = image.alphaInfo.hasAlpha
        let hasTransparentPixels = containsTransparentPixels(normalized)
        let convertedToSRGB = assumedSRGB == false && sourceName != outputColorSpaceName

        return (
            normalized,
            ImageNormalizationInfo(
                sourceColorSpaceName: sourceName,
                outputColorSpaceName: outputColorSpaceName,
                assumedSRGB: assumedSRGB,
                convertedToSRGB: convertedToSRGB,
                hasAlphaChannel: hasAlphaChannel,
                hasTransparentPixels: hasTransparentPixels
            )
        )
    }

    public static func makeOpaque(_ image: CGImage, backgroundColor: CGColor) throws -> CGImage {
        let colorSpace = outputColorSpace
        let width = image.width
        let height = image.height
        var rgbaPixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rgbaPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGImageByteOrderInfo.order32Big.rawValue
        ) else {
            throw ImagePreparationError.cannotCreateContext
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(backgroundColor.converted(to: colorSpace, intent: .defaultIntent, options: nil) ?? backgroundColor)
        context.fill(rect)
        context.draw(image, in: rect)

        var rgbPixels = [UInt8](repeating: 0, count: width * height * 3)
        for pixelIndex in 0..<(width * height) {
            let rgbaIndex = pixelIndex * 4
            let rgbIndex = pixelIndex * 3
            rgbPixels[rgbIndex] = rgbaPixels[rgbaIndex]
            rgbPixels[rgbIndex + 1] = rgbaPixels[rgbaIndex + 1]
            rgbPixels[rgbIndex + 2] = rgbaPixels[rgbaIndex + 2]
        }

        let data = Data(rgbPixels) as CFData
        guard let provider = CGDataProvider(data: data),
              let opaqueImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 24,
                bytesPerRow: width * 3,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              )
        else {
            throw ImagePreparationError.cannotCreateImage
        }

        return opaqueImage
    }

    private static func renderSRGB(
        _ image: CGImage,
        inputColorSpace: CGColorSpace,
        outputColorSpace: CGColorSpace
    ) throws -> CGImage {
        let source = CIImage(cgImage: image, options: [.colorSpace: inputColorSpace])
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let context = CIContext(options: [
            .workingColorSpace: outputColorSpace,
            .outputColorSpace: outputColorSpace
        ])

        guard let rendered = context.createCGImage(source, from: rect, format: .RGBA8, colorSpace: outputColorSpace) else {
            throw ImagePreparationError.cannotCreateImage
        }

        return rendered
    }

    private static func containsTransparentPixels(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: outputColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for index in stride(from: 3, to: pixels.count, by: 4) where pixels[index] < UInt8.max {
            return true
        }

        return false
    }

    private static func colorSpaceName(_ colorSpace: CGColorSpace?) -> String {
        guard let colorSpace else {
            return outputColorSpaceName
        }

        if colorSpace.name == CGColorSpace.sRGB {
            return outputColorSpaceName
        }

        if colorSpace.name == CGColorSpace.displayP3 {
            return "Display P3"
        }

        return colorSpace.name as String? ?? "未知色彩空间"
    }
}

private extension CGImageAlphaInfo {
    var hasAlpha: Bool {
        switch self {
        case .premultipliedLast, .premultipliedFirst, .last, .first, .alphaOnly:
            true
        case .none, .noneSkipLast, .noneSkipFirst:
            false
        @unknown default:
            false
        }
    }
}
