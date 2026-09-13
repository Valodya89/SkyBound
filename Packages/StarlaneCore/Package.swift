// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StarlaneCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StarlaneCore", targets: ["StarlaneCore"])
    ],
    targets: [
        .target(
            name: "StarlaneCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "StarlaneCoreTests",
            dependencies: ["StarlaneCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
