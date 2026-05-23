import AppKit
import CoreGraphics
import Foundation

struct ExportPreviewSlotGroup: Identifiable {
    let pixelSize: Int
    let slots: [IconSlot]

    var id: Int {
        pixelSize
    }

    var usageLabels: [String] {
        slots.map(\.previewUsageLabel)
    }
}

struct ExportIconPreview: Identifiable {
    let group: ExportPreviewSlotGroup
    let cgImage: CGImage
    let previewImage: NSImage

    var id: Int {
        group.id
    }

    var pixelSize: Int {
        group.pixelSize
    }

    var sizeLabel: String {
        "\(group.pixelSize)px"
    }

    var usageLabels: [String] {
        group.usageLabels
    }
}

enum ExportPreviewGenerator {
    static func previewGroups(for preset: IconPlatformPreset) -> [ExportPreviewSlotGroup] {
        let groupedSlots = Dictionary(grouping: preset.slots, by: \.pixelSize)

        return groupedSlots
            .map { pixelSize, slots in
                ExportPreviewSlotGroup(pixelSize: pixelSize, slots: slots)
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
        try previews(
            from: sourceImage,
            options: .init(mode: mode),
            preset: preset,
            opaqueBackgroundColor: opaqueBackgroundColor
        )
    }

    static func previews(
        from sourceImage: CGImage,
        options: ImagePreparationOptions,
        preset: IconPlatformPreset,
        opaqueBackgroundColor: CGColor? = nil
    ) throws -> [ExportIconPreview] {
        try previewGroups(for: preset).map { group in
            let image = try IconResampling.render(
                sourceImage,
                options: options,
                pixelSize: group.pixelSize,
                opaqueBackgroundColor: opaqueBackgroundColor
            )
            return ExportIconPreview(
                group: group,
                cgImage: image,
                previewImage: NSImage(
                    cgImage: image,
                    size: NSSize(width: group.pixelSize, height: group.pixelSize)
                )
            )
        }
    }
}

private extension IconSlot {
    var previewUsageLabel: String {
        "\(previewIdiomLabel) · \(size) · \(scale)"
    }

    private var previewIdiomLabel: String {
        switch idiom {
        case "iphone":
            "iPhone"
        case "ipad":
            "iPad"
        case "ios-marketing":
            "App Store"
        case "mac":
            "macOS"
        default:
            idiom
        }
    }
}
