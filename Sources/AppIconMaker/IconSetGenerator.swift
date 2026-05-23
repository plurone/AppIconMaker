import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum IconSetGeneratorError: LocalizedError {
    case cannotCreateDestination(URL)
    case cannotFinalizeImage(URL)
    case cannotResizeImage(size: Int)

    public var errorDescription: String? {
        switch self {
        case let .cannotCreateDestination(url):
            "无法创建图片文件：\(url.lastPathComponent)。"
        case let .cannotFinalizeImage(url):
            "无法写入图片文件：\(url.lastPathComponent)。"
        case let .cannotResizeImage(size):
            "无法缩放 \(size)x\(size) 图标。"
        }
    }
}

public struct IconSetGenerator {
    private let fileManager: FileManager

    private static var defaultOpaqueBackgroundColor: CGColor {
        CGColor(gray: 0, alpha: 1)
    }

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func generate(from sourceURL: URL, preset: IconPlatformPreset, outputDirectory: URL) throws -> URL {
        let validatedImage = try ImageValidator.validatePNG(at: sourceURL)
        return try generate(from: validatedImage.normalizedCGImage, preset: preset, outputDirectory: outputDirectory)
    }

    @discardableResult
    public func generate(from sourceImage: CGImage, preset: IconPlatformPreset, outputDirectory: URL) throws -> URL {
        try generate(preset: preset, outputDirectory: outputDirectory) { slot in
            let image = try IconResampling.resize(sourceImage, pixelSize: slot.pixelSize)
            if preset == .iosUniversal {
                return try ImageNormalizer.makeOpaque(image, backgroundColor: Self.defaultOpaqueBackgroundColor)
            }
            return image
        }
    }

    @discardableResult
    public func generate(
        from sourceImage: CGImage,
        mode: ImagePreparationMode,
        preset: IconPlatformPreset,
        outputDirectory: URL,
        opaqueBackgroundColor: CGColor? = nil
    ) throws -> URL {
        try generate(
            from: sourceImage,
            options: .init(mode: mode),
            preset: preset,
            outputDirectory: outputDirectory,
            opaqueBackgroundColor: opaqueBackgroundColor
        )
    }

    @discardableResult
    public func generate(
        from sourceImage: CGImage,
        options: ImagePreparationOptions,
        preset: IconPlatformPreset,
        outputDirectory: URL,
        opaqueBackgroundColor: CGColor? = nil
    ) throws -> URL {
        try generate(preset: preset, outputDirectory: outputDirectory) { slot in
            try IconResampling.render(
                sourceImage,
                options: options,
                pixelSize: slot.pixelSize,
                opaqueBackgroundColor: opaqueBackgroundColor
            )
        }
    }

    private func generate(
        preset: IconPlatformPreset,
        outputDirectory: URL,
        imageForSlot: (IconSlot) throws -> CGImage
    ) throws -> URL {
        let appIconSetURL = outputDirectory.appendingPathComponent(preset.appIconSetName, isDirectory: true)

        if fileManager.fileExists(atPath: appIconSetURL.path) {
            try fileManager.removeItem(at: appIconSetURL)
        }

        try fileManager.createDirectory(at: appIconSetURL, withIntermediateDirectories: true)

        for slot in preset.slots {
            let resized = try imageForSlot(slot)
            let outputURL = appIconSetURL.appendingPathComponent(slot.filename)
            try writePNG(resized, to: outputURL)
        }

        let contents = AssetCatalogContents(
            images: preset.slots.map {
                .init(idiom: $0.idiom, size: $0.size, scale: $0.scale, filename: $0.filename)
            },
            info: .init(author: "xcode", version: 1)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json = try encoder.encode(contents)
        try json.write(to: appIconSetURL.appendingPathComponent("Contents.json"), options: .atomic)

        return appIconSetURL
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw IconSetGeneratorError.cannotCreateDestination(url)
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw IconSetGeneratorError.cannotFinalizeImage(url)
        }
    }
}

enum IconResampling {
    private static var outputColorSpace: CGColorSpace {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    static func resize(_ image: CGImage, pixelSize: Int) throws -> CGImage {
        try render(
            image,
            drawRect: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
            pixelSize: pixelSize,
            opaqueBackgroundColor: nil
        )
    }

    static func render(
        _ image: CGImage,
        mode: ImagePreparationMode,
        pixelSize: Int,
        opaqueBackgroundColor: CGColor? = nil
    ) throws -> CGImage {
        try render(
            image,
            options: .init(mode: mode),
            pixelSize: pixelSize,
            opaqueBackgroundColor: opaqueBackgroundColor
        )
    }

    static func render(
        _ image: CGImage,
        options: ImagePreparationOptions,
        pixelSize: Int,
        opaqueBackgroundColor: CGColor? = nil
    ) throws -> CGImage {
        try render(
            image,
            drawRect: ImagePreparer.drawRect(for: image, options: options, pixelSize: pixelSize),
            pixelSize: pixelSize,
            opaqueBackgroundColor: opaqueBackgroundColor
        )
    }

    private static func render(
        _ image: CGImage,
        drawRect: CGRect,
        pixelSize: Int,
        opaqueBackgroundColor: CGColor?
    ) throws -> CGImage {
        let colorSpace = outputColorSpace
        let targetRect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        let scale = drawRect.width / CGFloat(image.width)
        let source = CIImage(cgImage: image, options: [.colorSpace: colorSpace])

        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            throw IconSetGeneratorError.cannotResizeImage(size: pixelSize)
        }

        filter.setValue(source, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let scaled = filter.outputImage else {
            throw IconSetGeneratorError.cannotResizeImage(size: pixelSize)
        }

        let positioned = scaled.transformed(by: CGAffineTransform(
            translationX: drawRect.minX - scaled.extent.minX,
            y: drawRect.minY - scaled.extent.minY
        ))
        let transparentCanvas = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: targetRect)
        let output = positioned
            .composited(over: transparentCanvas)
            .cropped(to: targetRect)
        let context = CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace
        ])

        guard let rendered = context.createCGImage(output, from: targetRect, format: .RGBA8, colorSpace: colorSpace) else {
            throw IconSetGeneratorError.cannotResizeImage(size: pixelSize)
        }

        if let opaqueBackgroundColor {
            return try ImageNormalizer.makeOpaque(rendered, backgroundColor: opaqueBackgroundColor)
        }

        return rendered
    }
}
