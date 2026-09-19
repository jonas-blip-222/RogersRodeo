// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrainerCore",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [.library(name: "TrainerCore", targets: ["TrainerCore"])],
    targets: [
        .target(name: "TrainerCore"),
        .testTarget(name: "TrainerCoreTests", dependencies: ["TrainerCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v6]
)
