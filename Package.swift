// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BarManager",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BarManager",
            path: "Sources/BarManager"
        )
    ]
)
