// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardWheelCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClipboardWheelCore", targets: ["ClipboardWheelCore"]),
    ],
    targets: [
        .target(name: "ClipboardWheelCore"),
        .testTarget(name: "ClipboardWheelCoreTests", dependencies: ["ClipboardWheelCore"]),
    ]
)
