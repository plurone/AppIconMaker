// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppIconMaker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AppIconMaker", targets: ["AppIconMaker"])
    ],
    targets: [
        .executableTarget(
            name: "AppIconMaker",
            path: "Sources/AppIconMaker"
        ),
        .testTarget(
            name: "AppIconMakerTests",
            dependencies: ["AppIconMaker"],
            path: "Tests/AppIconMakerTests"
        )
    ]
)
