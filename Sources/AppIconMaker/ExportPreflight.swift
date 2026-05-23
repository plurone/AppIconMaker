import CoreGraphics
import Foundation

public enum ExportIssueSeverity: Equatable {
    case warning
    case blocking
}

public enum ExportPreflightIssueKind: Equatable {
    case appStoreIconContainsAlpha
    case sourceWillUpscale(scale: Double)
    case transparentContentTooSmall(coverage: Double)
    case outputDirectoryUnavailable
    case outputDirectoryNotWritable
    case existingAppIconSetWillBeReplaced
}

public struct ExportPreflightIssue: Equatable {
    public let kind: ExportPreflightIssueKind
    public let severity: ExportIssueSeverity

    public var title: String {
        switch kind {
        case .appStoreIconContainsAlpha:
            "App Store 图标包含透明像素"
        case .sourceWillUpscale:
            "源图会被放大"
        case .transparentContentTooSmall:
            "透明填充后视觉占比偏小"
        case .outputDirectoryUnavailable:
            "导出目录不可用"
        case .outputDirectoryNotWritable:
            "导出目录不可写"
        case .existingAppIconSetWillBeReplaced:
            "将替换已有 AppIcon.appiconset"
        }
    }

    public var message: String {
        switch kind {
        case .appStoreIconContainsAlpha:
            "iOS App Store 1024x1024 图标不应包含透明像素。请改用居中裁剪或提供不透明 PNG。"
        case let .sourceWillUpscale(scale):
            "当前适配方式会把源图放大约 \(Self.decimalFormatter.string(from: scale as NSNumber) ?? "1.0")x，可能导致小尺寸图标发虚。"
        case let .transparentContentTooSmall(coverage):
            "图形只占母版较短边约 \(Self.percentFormatter.string(from: coverage as NSNumber) ?? "0%")，小尺寸图标可能显得过小。"
        case .outputDirectoryUnavailable:
            "请选择一个已经存在的文件夹作为导出目录。"
        case .outputDirectoryNotWritable:
            "当前应用没有权限写入所选目录。"
        case .existingAppIconSetWillBeReplaced:
            "继续导出会删除并重新生成该目录中的 AppIcon.appiconset。"
        }
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

public struct ExportPreflightResult: Equatable {
    public let issues: [ExportPreflightIssue]

    public var blockingIssues: [ExportPreflightIssue] {
        issues.filter { $0.severity == .blocking }
    }

    public var warnings: [ExportPreflightIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var canExport: Bool {
        blockingIssues.isEmpty
    }
}

public struct ExportQualityCheckResult: Equatable {
    public let issues: [ExportPreflightIssue]

    public var blockingIssues: [ExportPreflightIssue] {
        issues.filter { $0.severity == .blocking }
    }

    public var warnings: [ExportPreflightIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var canExport: Bool {
        blockingIssues.isEmpty
    }
}

public struct ExportSummary: Equatable {
    public let outputURL: URL
    public let platformName: String
    public let preparationName: String
    public let generatedPNGCount: Int
    public let generatedFileCount: Int
}

public enum ExportQualityCheck {
    public static let transparentCoverageWarningThreshold = 0.60

    public static func inspect(
        source: ValidatedImage,
        preparedImage: PreparedImage,
        preset: IconPlatformPreset,
        willCompositeOpaqueBackground: Bool = false
    ) -> ExportQualityCheckResult {
        inspect(
            sourceWidth: source.width,
            sourceHeight: source.height,
            preparedImage: preparedImage,
            preset: preset,
            willCompositeOpaqueBackground: willCompositeOpaqueBackground
        )
    }

    public static func inspect(
        sourceWidth: Int,
        sourceHeight: Int,
        preparedImage: PreparedImage,
        preset: IconPlatformPreset,
        willCompositeOpaqueBackground: Bool = false
    ) -> ExportQualityCheckResult {
        var issues: [ExportPreflightIssue] = []

        if preset == .iosUniversal,
           willCompositeOpaqueBackground == false,
           containsTransparentPixels(preparedImage.cgImage) {
            issues.append(.init(kind: .appStoreIconContainsAlpha, severity: .blocking))
        }

        let scale = preparationScale(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            options: preparedImage.options
        )
        if scale > 1.0 {
            issues.append(.init(kind: .sourceWillUpscale(scale: scale), severity: .warning))
        }

        if preparedImage.mode == .transparentPadding {
            let coverage = transparentContentCoverage(
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                options: preparedImage.options
            )
            if coverage < transparentCoverageWarningThreshold {
                issues.append(.init(kind: .transparentContentTooSmall(coverage: coverage), severity: .warning))
            }
        }

        return .init(issues: issues)
    }

    private static func preparationScale(sourceWidth: Int, sourceHeight: Int, options: ImagePreparationOptions) -> Double {
        let sourceWidth = Double(sourceWidth)
        let sourceHeight = Double(sourceHeight)
        let canvasSize = Double(ImagePreparer.outputPixelSize)
        let options = options.normalized

        switch options.mode {
        case .centerCrop:
            return max(canvasSize / sourceWidth, canvasSize / sourceHeight) * options.contentScale
        case .transparentPadding:
            return min(canvasSize / sourceWidth, canvasSize / sourceHeight) * options.contentScale
        }
    }

    private static func transparentContentCoverage(
        sourceWidth: Int,
        sourceHeight: Int,
        options: ImagePreparationOptions
    ) -> Double {
        let shorterSide = Double(min(sourceWidth, sourceHeight))
        let longerSide = Double(max(sourceWidth, sourceHeight))
        return min((shorterSide / longerSide) * options.normalized.contentScale, 1.0)
    }

    private static func containsTransparentPixels(_ image: CGImage) -> Bool {
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
            return false
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for index in stride(from: 3, to: pixels.count, by: 4) where pixels[index] < UInt8.max {
            return true
        }
        return false
    }
}

public enum ExportPreflight {
    public static let transparentCoverageWarningThreshold = ExportQualityCheck.transparentCoverageWarningThreshold

    public static func inspect(
        source: ValidatedImage,
        preparedImage: PreparedImage,
        preset: IconPlatformPreset,
        outputDirectory: URL,
        willCompositeOpaqueBackground: Bool = false,
        fileManager: FileManager = .default
    ) -> ExportPreflightResult {
        inspect(
            sourceWidth: source.width,
            sourceHeight: source.height,
            preparedImage: preparedImage,
            preset: preset,
            outputDirectory: outputDirectory,
            willCompositeOpaqueBackground: willCompositeOpaqueBackground,
            fileManager: fileManager
        )
    }

    public static func inspect(
        sourceWidth: Int,
        sourceHeight: Int,
        preparedImage: PreparedImage,
        preset: IconPlatformPreset,
        outputDirectory: URL,
        willCompositeOpaqueBackground: Bool = false,
        fileManager: FileManager = .default
    ) -> ExportPreflightResult {
        var issues: [ExportPreflightIssue] = []

        if !directoryExists(at: outputDirectory, fileManager: fileManager) {
            issues.append(.init(kind: .outputDirectoryUnavailable, severity: .blocking))
        } else if !fileManager.isWritableFile(atPath: outputDirectory.path) {
            issues.append(.init(kind: .outputDirectoryNotWritable, severity: .blocking))
        }

        let appIconSetURL = outputDirectory.appendingPathComponent(preset.appIconSetName, isDirectory: true)
        if fileManager.fileExists(atPath: appIconSetURL.path) {
            issues.append(.init(kind: .existingAppIconSetWillBeReplaced, severity: .warning))
        }

        let qualityCheck = ExportQualityCheck.inspect(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            preparedImage: preparedImage,
            preset: preset,
            willCompositeOpaqueBackground: willCompositeOpaqueBackground
        )
        issues.append(contentsOf: qualityCheck.issues)

        return .init(issues: issues)
    }

    public static func summary(
        outputURL: URL,
        preset: IconPlatformPreset,
        preparationMode: ImagePreparationMode
    ) -> ExportSummary {
        summary(
            outputURL: outputURL,
            preset: preset,
            preparationOptions: .init(mode: preparationMode)
        )
    }

    public static func summary(
        outputURL: URL,
        preset: IconPlatformPreset,
        preparationOptions: ImagePreparationOptions
    ) -> ExportSummary {
        ExportSummary(
            outputURL: outputURL,
            platformName: preset.displayName,
            preparationName: preparationOptions.displayDescription,
            generatedPNGCount: preset.slots.count,
            generatedFileCount: preset.slots.count + 1
        )
    }

    private static func directoryExists(at url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
