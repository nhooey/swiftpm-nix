// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "Counter",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2")
  ],
  targets: [
    .executableTarget(
      name: "Counter",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ])
  ]
)
