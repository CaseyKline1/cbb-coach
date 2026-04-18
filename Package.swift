// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CBBCoach",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CBBCoachCore", targets: ["CBBCoachCore"]),
        .executable(name: "CBBCoachCLI", targets: ["CBBCoachCLI"])
    ],
    targets: [
        .target(
            name: "CBBCoachCore",
            resources: [
                .copy("Resources/d1-conferences.2026.json")
            ]
        ),
        .executableTarget(name: "CBBCoachCLI", dependencies: ["CBBCoachCore"]),
        .testTarget(name: "CBBCoachCoreTests", dependencies: ["CBBCoachCore"])
    ]
)
