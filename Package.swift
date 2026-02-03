// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Eraser",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "Eraser", targets: ["Eraser"])
    ],
    targets: [
        .target(
            name: "Eraser",
            path: "Sources/Eraser"
        )
    ]
)
