import AppKit
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import AppIconMaker

@Suite("AppIcon generation")
struct IconSetGeneratorTests {
    @Test("rejects non-PNG files")
    func rejectsNonPNGFiles() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("icon.txt")
        try "not an image".write(to: url, atomically: true, encoding: .utf8)

        #expect(throws: ImageValidationError.notPNG) {
            try ImageValidator.loadPNG(at: url)
        }
    }

    @Test("rejects unreadable PNG files")
    func rejectsUnreadablePNGFiles() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("icon.png")
        try "not an image".write(to: url, atomically: true, encoding: .utf8)

        #expect(throws: ImageValidationError.unreadable) {
            try ImageValidator.loadPNG(at: url)
        }
    }

    @Test("accepts readable PNG files that are not 1024 square")
    func acceptsArbitraryPNGSize() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("icon.png")
        try writePNG(makeImage(width: 512, height: 1024), to: url)

        let image = try ImageValidator.loadPNG(at: url)
        #expect(image.width == 512)
        #expect(image.height == 1024)
    }

    @Test("center crop prepares wide and tall images as full 1024 square")
    func centerCropPreparesSquareImages() throws {
        let wide = try ImagePreparer.prepare(makeImage(width: 2048, height: 1024), mode: .centerCrop)
        let tall = try ImagePreparer.prepare(makeImage(width: 1024, height: 2048), mode: .centerCrop)

        #expect(wide.width == 1024)
        #expect(wide.height == 1024)
        #expect(tall.width == 1024)
        #expect(tall.height == 1024)
        #expect(try alpha(atX: 0, y: 0, in: wide.cgImage) == 255)
        #expect(try alpha(atX: 1023, y: 1023, in: tall.cgImage) == 255)
    }

    @Test("transparent padding prepares wide and tall images with transparent edges")
    func transparentPaddingPreparesSquareImages() throws {
        let wide = try ImagePreparer.prepare(makeImage(width: 2048, height: 1024), mode: .transparentPadding)
        let tall = try ImagePreparer.prepare(makeImage(width: 1024, height: 2048), mode: .transparentPadding)

        #expect(wide.width == 1024)
        #expect(wide.height == 1024)
        #expect(tall.width == 1024)
        #expect(tall.height == 1024)
        #expect(try alpha(atX: 512, y: 0, in: wide.cgImage) == 0)
        #expect(try alpha(atX: 0, y: 512, in: tall.cgImage) == 0)
    }

    @Test("generates iOS universal icon set files and Contents.json")
    func generatesIOSUniversalIconSet() throws {
        try assertGeneratedIconSet(for: .iosUniversal)
    }

    @Test("generates macOS icon set files and Contents.json")
    func generatesMacOSIconSet() throws {
        try assertGeneratedIconSet(for: .macOS)
    }

    @Test("generates icon sets from a prepared source without changing metadata")
    func generatesIconSetFromPreparedSource() throws {
        let directory = try temporaryDirectory()
        let prepared = try ImagePreparer.prepare(makeImage(width: 2048, height: 1024), mode: .centerCrop)

        let outputURL = try IconSetGenerator().generate(
            from: prepared.cgImage,
            preset: .iosUniversal,
            outputDirectory: directory
        )

        let contentsURL = outputURL.appendingPathComponent("Contents.json")
        let contentsData = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(AssetCatalogContents.self, from: contentsData)

        #expect(contents.info == .init(author: "xcode", version: 1))
        #expect(contents.images.count == IconPlatformPreset.iosUniversal.slots.count)
    }

    @Test("preflight blocks transparent iOS marketing icons")
    func preflightBlocksTransparentIOSMarketingIcons() throws {
        let directory = try temporaryDirectory()
        let prepared = try ImagePreparer.prepare(makeImage(width: 2048, height: 1024), mode: .transparentPadding)

        let result = ExportPreflight.inspect(
            sourceWidth: 2048,
            sourceHeight: 1024,
            preparedImage: prepared,
            preset: .iosUniversal,
            outputDirectory: directory
        )

        #expect(result.canExport == false)
        #expect(result.blockingIssues.contains {
            $0.kind == .appStoreIconContainsAlpha
        })
    }

    @Test("preflight allows transparent iOS sources when opaque background will be composited")
    func preflightAllowsOpaqueCompositedIOSMarketingIcons() throws {
        let directory = try temporaryDirectory()
        let prepared = try ImagePreparer.prepare(makeImage(width: 2048, height: 1024), mode: .transparentPadding)

        let result = ExportPreflight.inspect(
            sourceWidth: 2048,
            sourceHeight: 1024,
            preparedImage: prepared,
            preset: .iosUniversal,
            outputDirectory: directory,
            willCompositeOpaqueBackground: true
        )

        #expect(result.canExport)
        #expect(result.blockingIssues.isEmpty)
    }

    @Test("preflight warns about upscaling and small transparent coverage")
    func preflightWarnsAboutExportQualityRisks() throws {
        let directory = try temporaryDirectory()
        let prepared = try ImagePreparer.prepare(makeImage(width: 256, height: 512), mode: .transparentPadding)

        let result = ExportPreflight.inspect(
            sourceWidth: 256,
            sourceHeight: 512,
            preparedImage: prepared,
            preset: .macOS,
            outputDirectory: directory
        )

        #expect(result.canExport)
        #expect(result.warnings.contains {
            $0.kind == .sourceWillUpscale(scale: 2.0)
        })
        #expect(result.warnings.contains {
            $0.kind == .transparentContentTooSmall(coverage: 0.5)
        })
    }

    @Test("preflight warns when export will replace an existing icon set")
    func preflightWarnsAboutReplacementRisk() throws {
        let directory = try temporaryDirectory()
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent(IconPlatformPreset.macOS.appIconSetName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let prepared = try ImagePreparer.prepare(makeImage(width: 1024, height: 1024), mode: .centerCrop)

        let result = ExportPreflight.inspect(
            sourceWidth: 1024,
            sourceHeight: 1024,
            preparedImage: prepared,
            preset: .macOS,
            outputDirectory: directory
        )

        #expect(result.canExport)
        #expect(result.warnings.contains {
            $0.kind == .existingAppIconSetWillBeReplaced
        })
    }

    @Test("preflight blocks missing export directories")
    func preflightBlocksMissingExportDirectories() throws {
        let directory = try temporaryDirectory().appendingPathComponent("Missing", isDirectory: true)
        let prepared = try ImagePreparer.prepare(makeImage(width: 1024, height: 1024), mode: .centerCrop)

        let result = ExportPreflight.inspect(
            sourceWidth: 1024,
            sourceHeight: 1024,
            preparedImage: prepared,
            preset: .macOS,
            outputDirectory: directory
        )

        #expect(result.canExport == false)
        #expect(result.blockingIssues.contains {
            $0.kind == .outputDirectoryUnavailable
        })
    }

    @Test("preflight blocks unwritable export directories")
    func preflightBlocksUnwritableExportDirectories() throws {
        let directory = try temporaryDirectory()
        try #require(chmod(directory.path, 0o500) == 0)
        defer {
            _ = chmod(directory.path, 0o700)
        }
        let prepared = try ImagePreparer.prepare(makeImage(width: 1024, height: 1024), mode: .centerCrop)

        let result = ExportPreflight.inspect(
            sourceWidth: 1024,
            sourceHeight: 1024,
            preparedImage: prepared,
            preset: .macOS,
            outputDirectory: directory
        )

        #expect(result.canExport == false)
        #expect(result.blockingIssues.contains {
            $0.kind == .outputDirectoryNotWritable
        })
    }

    @Test("export summary reports platform, mode, and generated counts")
    func exportSummaryReportsGeneratedCounts() throws {
        let directory = try temporaryDirectory()
        let outputURL = directory.appendingPathComponent(IconPlatformPreset.iosUniversal.appIconSetName)

        let summary = ExportPreflight.summary(
            outputURL: outputURL,
            preset: .iosUniversal,
            preparationMode: .centerCrop
        )

        #expect(summary.outputURL == outputURL)
        #expect(summary.platformName == "iOS/iPadOS")
        #expect(summary.preparationName == "居中裁剪")
        #expect(summary.generatedPNGCount == IconPlatformPreset.iosUniversal.slots.count)
        #expect(summary.generatedFileCount == IconPlatformPreset.iosUniversal.slots.count + 1)
    }

    @Test("slot-aware export applies transparent padding at each target size")
    func slotAwareExportAppliesTransparentPaddingAtEachTargetSize() throws {
        let directory = try temporaryDirectory()
        let outputURL = try IconSetGenerator().generate(
            from: makeImage(width: 80, height: 40),
            mode: .transparentPadding,
            preset: .iosUniversal,
            outputDirectory: directory
        )

        let image = try #require(loadImage(at: outputURL.appendingPathComponent("Icon-iPad-20x20.png")))

        #expect(image.width == 20)
        #expect(image.height == 20)
        #expect(try alpha(atX: 10, y: 0, in: image) == 0)
        #expect(try alpha(atX: 10, y: 10, in: image) == 255)
        #expect(try alpha(atX: 10, y: 19, in: image) == 0)
    }

    @Test("small icon resampling keeps antialiased alpha edges")
    func smallIconResamplingKeepsAntialiasedAlphaEdges() throws {
        let image = try makeVerticalAlphaEdgeImage(width: 103, height: 103, edgeX: 50)
        let resized = try IconResampling.resize(image, pixelSize: 20)
        let centerRowAlphas = try (0..<20).map { try alpha(atX: $0, y: 10, in: resized) }

        #expect(centerRowAlphas.contains { $0 > 0 && $0 < 255 })
    }

    @Test("normalizer converts display P3 inputs to sRGB")
    func normalizerConvertsDisplayP3InputsToSRGB() throws {
        let displayP3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let image = try makeImage(width: 32, height: 32, colorSpace: displayP3)

        let normalized = try ImageNormalizer.normalize(image)

        #expect(normalized.1.sourceColorSpaceName == "Display P3")
        #expect(normalized.1.outputColorSpaceName == "sRGB")
        #expect(normalized.1.convertedToSRGB)
        #expect(normalized.0.colorSpace?.name == CGColorSpace.sRGB)
    }

    @Test("iOS export composites transparent padding over opaque background")
    func iOSExportCompositesTransparentPaddingOverOpaqueBackground() throws {
        let directory = try temporaryDirectory()
        let outputURL = try IconSetGenerator().generate(
            from: makeImage(width: 80, height: 40),
            mode: .transparentPadding,
            preset: .iosUniversal,
            outputDirectory: directory,
            opaqueBackgroundColor: NSColor.white.cgColor
        )

        let imageURL = outputURL.appendingPathComponent("Icon-iPad-20x20.png")
        let image = try #require(loadImage(at: imageURL))

        #expect(pngHasAlpha(at: imageURL) == false)
        #expect(try alpha(atX: 10, y: 0, in: image) == 255)
        #expect(try alpha(atX: 10, y: 10, in: image) == 255)
        #expect(try alpha(atX: 10, y: 19, in: image) == 255)
    }

    @Test("iOS URL export strips alpha channel from imported PNGs")
    func iOSURLExportStripsAlphaChannelFromImportedPNGs() throws {
        let directory = try temporaryDirectory()
        let sourceURL = directory.appendingPathComponent("source.png")
        try writePNG(makeImage(width: 1024, height: 1024), to: sourceURL)

        let outputURL = try IconSetGenerator().generate(
            from: sourceURL,
            preset: .iosUniversal,
            outputDirectory: directory
        )

        #expect(pngHasAlpha(at: outputURL.appendingPathComponent("Icon-AppStore-1024x1024.png")) == false)
        #expect(pngHasAlpha(at: outputURL.appendingPathComponent("Icon-iPad-20x20.png")) == false)
    }

    @Test("macOS export preserves transparent padding")
    func macOSExportPreservesTransparentPadding() throws {
        let directory = try temporaryDirectory()
        let outputURL = try IconSetGenerator().generate(
            from: makeImage(width: 80, height: 40),
            mode: .transparentPadding,
            preset: .macOS,
            outputDirectory: directory
        )

        let image = try #require(loadImage(at: outputURL.appendingPathComponent("icon_16x16.png")))

        #expect(pngHasAlpha(at: outputURL.appendingPathComponent("icon_16x16.png")))
        #expect(try alpha(atX: 8, y: 0, in: image) == 0)
        #expect(try alpha(atX: 8, y: 8, in: image) == 255)
        #expect(try alpha(atX: 8, y: 15, in: image) == 0)
    }

    @Test("export preview slots use unique sorted output sizes")
    func exportPreviewSlotsUseUniqueSortedOutputSizes() {
        let iOSSizes = ExportPreviewGenerator.previewSlots(for: .iosUniversal).map(\.pixelSize)
        let macOSSizes = ExportPreviewGenerator.previewSlots(for: .macOS).map(\.pixelSize)

        #expect(iOSSizes == [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024])
        #expect(macOSSizes == [16, 32, 64, 128, 256, 512, 1024])
    }

    @Test("export previews render with their target pixel sizes")
    func exportPreviewsRenderWithTargetPixelSizes() throws {
        let previews = try ExportPreviewGenerator.previews(
            from: makeImage(width: 80, height: 40),
            mode: .transparentPadding,
            preset: .macOS
        )

        #expect(previews.count == ExportPreviewGenerator.previewSlots(for: .macOS).count)

        for preview in previews {
            #expect(preview.cgImage.width == preview.pixelSize)
            #expect(preview.cgImage.height == preview.pixelSize)
            #expect(preview.previewImage.size == NSSize(width: preview.pixelSize, height: preview.pixelSize))
        }
    }

    private func assertGeneratedIconSet(for preset: IconPlatformPreset) throws {
        let directory = try temporaryDirectory()
        let sourceURL = directory.appendingPathComponent("source.png")
        try writePNG(makeImage(width: 1024, height: 1024), to: sourceURL)

        let outputURL = try IconSetGenerator().generate(from: sourceURL, preset: preset, outputDirectory: directory)
        #expect(outputURL.lastPathComponent == "AppIcon.appiconset")

        for slot in preset.slots {
            let imageURL = outputURL.appendingPathComponent(slot.filename)
            #expect(FileManager.default.fileExists(atPath: imageURL.path))

            let image = try #require(loadImage(at: imageURL))
            #expect(image.width == slot.pixelSize)
            #expect(image.height == slot.pixelSize)
        }

        let contentsURL = outputURL.appendingPathComponent("Contents.json")
        let contentsData = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(AssetCatalogContents.self, from: contentsData)

        #expect(contents.info == .init(author: "xcode", version: 1))
        #expect(contents.images.count == preset.slots.count)

        for slot in preset.slots {
            #expect(contents.images.contains(.init(
                idiom: slot.idiom,
                size: slot.size,
                scale: slot.scale,
                filename: slot.filename
            )))
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppIconMakerTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeImage(
        width: Int,
        height: Int,
        colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    ) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Could not create test image context")
            throw TestFailure()
        }

        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage() else {
            Issue.record("Could not create test image")
            throw TestFailure()
        }

        return image
    }

    private func makeVerticalAlphaEdgeImage(width: Int, height: Int, edgeX: Int) throws -> CGImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let alpha: UInt8 = x < edgeX ? 255 : 0
                let index = (y * width + x) * 4
                pixels[index] = alpha
                pixels[index + 1] = alpha
                pixels[index + 2] = alpha
                pixels[index + 3] = alpha
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            Issue.record("Could not create alpha edge test image")
            throw TestFailure()
        }

        return image
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            Issue.record("Could not create PNG destination")
            throw TestFailure()
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            Issue.record("Could not write PNG")
            throw TestFailure()
        }
    }

    private func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func pngHasAlpha(at url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }

        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let hasAlpha = properties[kCGImagePropertyHasAlpha] as? Bool {
            return hasAlpha
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return false
        }

        return image.alphaInfo.hasAlpha
    }

    private func alpha(atX x: Int, y: Int, in image: CGImage) throws -> UInt8 {
        try component(3, atX: x, y: y, in: image)
    }

    private func component(_ component: Int, atX x: Int, y: Int, in image: CGImage) throws -> UInt8 {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Could not create alpha sampling context")
            throw TestFailure()
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels[(y * width + x) * 4 + component]
    }
}

private struct TestFailure: Error {}

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
