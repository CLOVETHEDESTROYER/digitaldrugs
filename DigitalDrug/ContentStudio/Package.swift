// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ZenWaveContentStudio",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ZenWaveStudio", targets: ["ZenWaveStudio"])],
    targets: [
        .executableTarget(name: "ZenWaveStudio", resources: [.copy("Resources")]),
        .testTarget(name: "ZenWaveStudioTests", dependencies: ["ZenWaveStudio"])
    ]
)
