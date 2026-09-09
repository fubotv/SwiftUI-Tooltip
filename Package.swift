// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUITooltip",
    platforms: [
        .iOS(.v16), .tvOS(.v16)
    ],
    products: [
        .library(
            name: "SwiftUITooltip",
            targets: ["SwiftUITooltip"]),
    ],
    targets: [
        .target(
            name: "SwiftUITooltip"
        )
    ]
)
