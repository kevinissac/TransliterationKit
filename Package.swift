// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TransliterationKit",
    platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "TransliterationKit", targets: ["TransliterationKit"]),
    ],
    targets: [
        .target(name: "TransliterationKit"),
        .testTarget(name: "TransliterationKitTests", dependencies: ["TransliterationKit"]),
    ]
)
