// swift-tools-version: 6.0
import PackageDescription

// macOS-Prüf-App mit denselben SwiftUI-Quellen. Das iPhone-Projekt bleibt das Xcode-Projekt.
let package = Package(
    name: "RogersRodeo",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "RogersRodeo", targets: ["TrainerDesktop"])],
    dependencies: [.package(path: "Packages/TrainerCore"), .package(path: "Packages/TrainerStorage")],
    targets: [.executableTarget(name: "TrainerDesktop", dependencies: ["TrainerCore", "TrainerStorage"],
        path: "Beratungstrainer", resources: [.process("Resources/Content"), .process("Resources/Illustrations")]),
        .testTarget(name: "TrainerPresentationTests", dependencies: ["TrainerDesktop"], path: "Tests/TrainerPresentationTests")],
    swiftLanguageModes: [.v6])
