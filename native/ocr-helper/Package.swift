// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ocr-helper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ocr-helper", targets: ["ocr-helper"])
    ],
    targets: [
        .executableTarget(
            name: "ocr-helper",
            linkerSettings: [
                .linkedFramework("Vision"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)