// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HeyMilo",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "HeyMilo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/HeyMilo"
        ),
    ]
)
