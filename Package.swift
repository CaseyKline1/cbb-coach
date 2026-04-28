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
        .executable(name: "CBBCoachCLI", targets: ["CBBCoachCLI"]),
        .executable(name: "CBBCoachBench", targets: ["CBBCoachBench"])
    ],
    targets: [
        .target(
            name: "CBBCoachCore",
            resources: [
                .process("Resources/js")
            ]
        ),
        .executableTarget(name: "CBBCoachCLI", dependencies: ["CBBCoachCore"]),
        .executableTarget(name: "CBBCoachBench", dependencies: ["CBBCoachCore"]),
        .testTarget(name: "CBBCoachCoreTests", dependencies: ["CBBCoachCore"])
    ]
)
