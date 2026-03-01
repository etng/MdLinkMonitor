// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "cbm",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "CBMCore",
            targets: ["CBMCore"]
        ),
        .executable(
            name: "cbm",
            targets: ["cbm"]
        ),
        .executable(
            name: "MdMonitor",
            targets: ["MdMonitor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1"),
    ],
    targets: [
        .target(
            name: "CBMCore"
        ),
        .executableTarget(
            name: "cbm",
            dependencies: ["CBMCore"]
        ),
        .executableTarget(
            name: "MdMonitor",
            dependencies: [
                "CBMCore",
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources/CBMMenuBar"
        ),
        .testTarget(
            name: "CBMCoreTests",
            dependencies: ["CBMCore"]
        ),
    ]
)
