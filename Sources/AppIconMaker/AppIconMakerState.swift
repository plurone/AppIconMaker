import AppKit
import Observation
import SwiftUI

@Observable
final class AppIconMakerState {
    var selectedPreset: IconPlatformPreset = .iosUniversal
    var preparationOptions = ImagePreparationOptions()
    var selectedImage: ValidatedImage?
    var preparedImage: PreparedImage?
    var status: ValidationStatus = .idle
    var exportSummary: ExportSummary?
    var exportPreviews: [ExportIconPreview] = []
    var selectedExportPreview: ExportIconPreview?
    var qualityCheckResult: ExportQualityCheckResult?
    var opaqueBackgroundColor = Color.black
    var isTargeted = false

    var canExport: Bool {
        preparedImage != nil
    }

    var selectedFileName: String? {
        selectedImage?.url.lastPathComponent
    }

    var exportOpaqueBackgroundColor: CGColor? {
        guard selectedPreset == .iosUniversal else {
            return nil
        }

        return NSColor(opaqueBackgroundColor).usingColorSpace(.sRGB)?.cgColor ?? NSColor.black.cgColor
    }

    var isDefaultComposition: Bool {
        preparationOptions.contentScale == 1.0
            && preparationOptions.horizontalOffset == 0.0
            && preparationOptions.verticalOffset == 0.0
    }

    func resetComposition() {
        preparationOptions = .init(mode: preparationOptions.mode)
    }

    func loadImage(at url: URL) {
        do {
            let image = try ImageValidator.loadPNG(at: url)
            selectedImage = image
            prepareSelectedImage()
        } catch {
            selectedImage = nil
            preparedImage = nil
            exportSummary = nil
            exportPreviews = []
            selectedExportPreview = nil
            qualityCheckResult = nil
            status = .failed(message: error.localizedDescription)
        }
    }

    func clearExportSummary() {
        exportSummary = nil
        if let selectedImage, let preparedImage {
            status = .ready(width: selectedImage.width, height: selectedImage.height, mode: preparedImage.mode)
        }
    }

    func refreshExportPreviews() {
        guard let selectedImage else {
            exportPreviews = []
            selectedExportPreview = nil
            return
        }

        do {
            exportPreviews = try ExportPreviewGenerator.previews(
                from: selectedImage.normalizedCGImage,
                options: preparationOptions,
                preset: selectedPreset,
                opaqueBackgroundColor: exportOpaqueBackgroundColor
            )
            selectedExportPreview = nil
        } catch {
            exportPreviews = []
            selectedExportPreview = nil
            status = .failed(message: error.localizedDescription)
        }
    }

    func prepareSelectedImage() {
        guard let selectedImage else {
            preparedImage = nil
            exportSummary = nil
            exportPreviews = []
            selectedExportPreview = nil
            qualityCheckResult = nil
            status = .idle
            return
        }

        do {
            var image = try ImagePreparer.prepare(selectedImage.normalizedCGImage, options: preparationOptions)
            if let exportOpaqueBackgroundColor {
                let opaqueImage = try ImageNormalizer.makeOpaque(image.cgImage, backgroundColor: exportOpaqueBackgroundColor)
                image = PreparedImage(
                    cgImage: opaqueImage,
                    previewImage: NSImage(cgImage: opaqueImage, size: NSSize(width: image.width, height: image.height)),
                    width: image.width,
                    height: image.height,
                    options: image.options
                )
            }
            let previews = try ExportPreviewGenerator.previews(
                from: selectedImage.normalizedCGImage,
                options: preparationOptions,
                preset: selectedPreset,
                opaqueBackgroundColor: exportOpaqueBackgroundColor
            )
            preparedImage = image
            exportPreviews = previews
            qualityCheckResult = ExportQualityCheck.inspect(
                source: selectedImage,
                preparedImage: image,
                preset: selectedPreset,
                willCompositeOpaqueBackground: exportOpaqueBackgroundColor != nil
            )
            exportSummary = nil
            selectedExportPreview = nil
            status = .ready(width: selectedImage.width, height: selectedImage.height, mode: preparationOptions.mode)
        } catch {
            preparedImage = nil
            exportSummary = nil
            exportPreviews = []
            selectedExportPreview = nil
            qualityCheckResult = nil
            status = .failed(message: error.localizedDescription)
        }
    }
}

enum ValidationStatus: Equatable {
    case idle
    case ready(width: Int, height: Int, mode: ImagePreparationMode)
    case failed(message: String)
    case exported(ExportSummary)
}
