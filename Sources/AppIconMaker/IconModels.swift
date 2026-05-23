import Foundation

public enum IconPlatformPreset: String, CaseIterable, Identifiable {
    case iosUniversal
    case macOS

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iosUniversal:
            "iOS/iPadOS"
        case .macOS:
            "macOS"
        }
    }

    public var appIconSetName: String {
        "AppIcon.appiconset"
    }

    public var slots: [IconSlot] {
        switch self {
        case .iosUniversal:
            [
                .init(idiom: "iphone", size: "20x20", scale: "2x", pixelSize: 40, filename: "Icon-iPhone-20x20@2x.png"),
                .init(idiom: "iphone", size: "20x20", scale: "3x", pixelSize: 60, filename: "Icon-iPhone-20x20@3x.png"),
                .init(idiom: "iphone", size: "29x29", scale: "2x", pixelSize: 58, filename: "Icon-iPhone-29x29@2x.png"),
                .init(idiom: "iphone", size: "29x29", scale: "3x", pixelSize: 87, filename: "Icon-iPhone-29x29@3x.png"),
                .init(idiom: "iphone", size: "40x40", scale: "2x", pixelSize: 80, filename: "Icon-iPhone-40x40@2x.png"),
                .init(idiom: "iphone", size: "40x40", scale: "3x", pixelSize: 120, filename: "Icon-iPhone-40x40@3x.png"),
                .init(idiom: "iphone", size: "60x60", scale: "2x", pixelSize: 120, filename: "Icon-iPhone-60x60@2x.png"),
                .init(idiom: "iphone", size: "60x60", scale: "3x", pixelSize: 180, filename: "Icon-iPhone-60x60@3x.png"),
                .init(idiom: "ipad", size: "20x20", scale: "1x", pixelSize: 20, filename: "Icon-iPad-20x20.png"),
                .init(idiom: "ipad", size: "20x20", scale: "2x", pixelSize: 40, filename: "Icon-iPad-20x20@2x.png"),
                .init(idiom: "ipad", size: "29x29", scale: "1x", pixelSize: 29, filename: "Icon-iPad-29x29.png"),
                .init(idiom: "ipad", size: "29x29", scale: "2x", pixelSize: 58, filename: "Icon-iPad-29x29@2x.png"),
                .init(idiom: "ipad", size: "40x40", scale: "1x", pixelSize: 40, filename: "Icon-iPad-40x40.png"),
                .init(idiom: "ipad", size: "40x40", scale: "2x", pixelSize: 80, filename: "Icon-iPad-40x40@2x.png"),
                .init(idiom: "ipad", size: "76x76", scale: "1x", pixelSize: 76, filename: "Icon-iPad-76x76.png"),
                .init(idiom: "ipad", size: "76x76", scale: "2x", pixelSize: 152, filename: "Icon-iPad-76x76@2x.png"),
                .init(idiom: "ipad", size: "83.5x83.5", scale: "2x", pixelSize: 167, filename: "Icon-iPad-83.5x83.5@2x.png"),
                .init(idiom: "ios-marketing", size: "1024x1024", scale: "1x", pixelSize: 1024, filename: "Icon-AppStore-1024x1024.png")
            ]
        case .macOS:
            [
                .init(idiom: "mac", size: "16x16", scale: "1x", pixelSize: 16, filename: "icon_16x16.png"),
                .init(idiom: "mac", size: "16x16", scale: "2x", pixelSize: 32, filename: "icon_16x16@2x.png"),
                .init(idiom: "mac", size: "32x32", scale: "1x", pixelSize: 32, filename: "icon_32x32.png"),
                .init(idiom: "mac", size: "32x32", scale: "2x", pixelSize: 64, filename: "icon_32x32@2x.png"),
                .init(idiom: "mac", size: "128x128", scale: "1x", pixelSize: 128, filename: "icon_128x128.png"),
                .init(idiom: "mac", size: "128x128", scale: "2x", pixelSize: 256, filename: "icon_128x128@2x.png"),
                .init(idiom: "mac", size: "256x256", scale: "1x", pixelSize: 256, filename: "icon_256x256.png"),
                .init(idiom: "mac", size: "256x256", scale: "2x", pixelSize: 512, filename: "icon_256x256@2x.png"),
                .init(idiom: "mac", size: "512x512", scale: "1x", pixelSize: 512, filename: "icon_512x512.png"),
                .init(idiom: "mac", size: "512x512", scale: "2x", pixelSize: 1024, filename: "icon_512x512@2x.png")
            ]
        }
    }
}

public struct IconSlot: Equatable, Sendable {
    public let idiom: String
    public let size: String
    public let scale: String
    public let pixelSize: Int
    public let filename: String

    public init(idiom: String, size: String, scale: String, pixelSize: Int, filename: String) {
        self.idiom = idiom
        self.size = size
        self.scale = scale
        self.pixelSize = pixelSize
        self.filename = filename
    }
}

struct AssetCatalogContents: Codable, Equatable {
    struct Image: Codable, Equatable {
        let idiom: String
        let size: String
        let scale: String
        let filename: String
    }

    struct Info: Codable, Equatable {
        let author: String
        let version: Int
    }

    let images: [Image]
    let info: Info
}
