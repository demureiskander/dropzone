// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dropzone",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Dropzone", targets: ["Dropzone"])],
    targets: [
        .target(name: "DropzoneCore"),
        .executableTarget(name: "Dropzone", dependencies: ["DropzoneCore"]),
        .testTarget(name: "DropzoneCoreTests", dependencies: ["DropzoneCore"])
    ]
)
