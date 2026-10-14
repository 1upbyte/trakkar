// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "TrakkarLiveTrackingSDK",
  platforms: [.iOS(.v15)],
  products: [.library(name: "TrakkarLiveTrackingSDK", targets: ["TrakkarLiveTrackingSDK"])],
  dependencies: [.package(url: "https://github.com/traccar/traccar-client-sdk.git", exact: "1.0.11")],
  targets: [.target(name: "TrakkarLiveTrackingSDK", dependencies: [
    .product(name: "TraccarClientSDK", package: "traccar-client-sdk")
  ], linkerSettings: [.linkedLibrary("sqlite3")])]
)
