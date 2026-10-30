// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MC1Services",
  platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v10)],
  products: [
    .library(name: "MC1Services", targets: ["MC1Services"]),
    .library(name: "MC1WatchShared", targets: ["MC1WatchShared"])
  ],
  dependencies: [
    .package(path: "../MeshCore")
  ],
  targets: [
    .target(
      name: "MC1Services",
      dependencies: ["MeshCore", "MC1WatchShared"]
    ),
    // What the iPhone and Apple Watch apps exchange over WatchConnectivity. Has no dependencies,
    // so the watch app builds it alone, without MeshCore or the rest of MC1Services.
    .target(
      name: "MC1WatchShared"
    ),
    .testTarget(
      name: "MC1ServicesTests",
      dependencies: [
        "MC1Services",
        "MC1WatchShared",
        .product(name: "MeshCoreTestSupport", package: "MeshCore")
      ]
    )
  ]
)
