// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyToDoBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MyToDoBar", targets: ["MyToDoBar"])
    ],
    targets: [
        .target(name: "MyToDoBarCore"),
        .target(
            name: "MyToDoBarKit",
            dependencies: ["MyToDoBarCore"]
        ),
        .executableTarget(
            name: "MyToDoBar",
            dependencies: ["MyToDoBarCore", "MyToDoBarKit"]
        ),
        .testTarget(
            name: "MyToDoBarCoreTests",
            dependencies: ["MyToDoBarCore"]
        ),
        .testTarget(
            name: "MyToDoBarTests",
            dependencies: ["MyToDoBarKit", "MyToDoBarCore"]
        )
    ]
)
