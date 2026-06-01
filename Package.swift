// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cockpit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Cockpit", targets: ["Cockpit"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Cockpit",
            dependencies: [],
            path: "Sources/Cockpit"
        ),
        .testTarget(
            name: "CockpitTests",
            dependencies: ["Cockpit"],
            path: "Tests"
        )
    ]
)
