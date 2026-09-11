// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkyBoundCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkyBoundCore", targets: ["SkyBoundCore"])
    ],
    targets: [
        .target(
            name: "SkyBoundCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "SkyBoundCoreTests",
            dependencies: ["SkyBoundCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
