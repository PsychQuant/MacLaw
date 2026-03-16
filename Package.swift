// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacLaw",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "maclaw", targets: ["MacLaw"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacLaw",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "MacLawTests",
            dependencies: ["MacLaw"]
        ),
    ]
)
