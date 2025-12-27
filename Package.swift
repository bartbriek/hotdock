// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Hotdock",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Hotdock", targets: ["Hotdock"]),
        .library(name: "HotdockCore", targets: ["HotdockCore"])
    ],
    targets: [
        .target(
            name: "HotdockCore",
            path: "Sources/HotdockCore"
        ),
        .executableTarget(
            name: "Hotdock",
            dependencies: ["HotdockCore"],
            path: "Sources/Hotdock"
        )
    ]
)
