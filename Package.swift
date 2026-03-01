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
            name: "CBMMenuBar",
            targets: ["CBMMenuBar"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
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
            name: "CBMMenuBar",
            dependencies: [
                "CBMCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "CBMCoreTests",
            dependencies: ["CBMCore"]
        ),
    ]
)
