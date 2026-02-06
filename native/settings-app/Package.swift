// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextShotSettings",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "text-shot-settings", targets: ["TextShotSettings"])
    ],
    targets: [
        .executableTarget(
            name: "TextShotSettings",
            path: "Sources/TextShotSettings"
        ),
        .testTarget(
            name: "TextShotSettingsTests",
            dependencies: ["TextShotSettings"],
            path: "Tests/TextShotSettingsTests"
        )
    ]
)
