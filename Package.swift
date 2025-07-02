// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CalendarSync",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "CalendarSync",
            targets: ["CalendarSync"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "CalendarSync",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),

        .testTarget(
            name: "CalendarSyncTests",
            dependencies: ["CalendarSync"]
        ),
    ]
) 