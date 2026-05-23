import AppKit
import CoreGraphics
import Foundation

struct ExportIconPreview: Identifiable {
    let id: String
    let slot: IconSlot
    let cgImage: CGImage
    let previewImage: NSImage

    var pixelSize: Int {
        slot.pixelSize
    }

    var sizeLabel: String {
        "\(slot.pixelSize)px"
    }

    var detailLabel: String {
        "\(slot.idiom) · \(slot.size) · \(slot.scale)"
    }
}

enum ExportPreviewGenerator {
    static func previewSlots(for preset: IconPlatformPreset) -> [IconSlot] {
        var seenPixelSizes = Set<Int>()
        return preset.slots
            .filter { slot in
                seenPixelSizes.insert(slot.pixelSize).inserted
            }
            .sorted { lhs, rhs in
                lhs.pixelSize < rhs.pixelSize
            }
    }

    static func previews(
        from sourceImage: CGImage,
        mode: ImagePreparationMode,
        preset: IconPlatformPreset,
        opaqueBackgroundColor: CGColor? = nil
    ) throws -> [ExportIconPreview] {
        try previewSlots(for: preset).map { slot in
            let image = try IconResampling.render(
                sourceImage,
                mode: mode,
                pixelSize: slot.pixelSize,
                opaqueBackgroundColor: opaqueBackgroundColor
            )
            return ExportIconPreview(
                id: "\(slot.pixelSize)",
                slot: slot,
                cgImage: image,
                previewImage: NSImage(
                    cgImage: image,
                    size: NSSize(width: slot.pixelSize, height: slot.pixelSize)
                )
            )
        }
    }
}
