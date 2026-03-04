// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "mdm",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "MdMCore",
            targets: ["MdMCore"]
        ),
        .executable(
            name: "mdm",
            targets: ["mdm"]
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
            name: "MdMCore"
        ),
        .executableTarget(
            name: "mdm",
            dependencies: ["MdMCore"],
            path: "Sources/mdm"
        ),
        .executableTarget(
            name: "MdMonitor",
            dependencies: [
                "MdMCore",
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources/MdMMenuBar",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MdMCoreTests",
            dependencies: ["MdMCore"]
        ),
    ]
)
