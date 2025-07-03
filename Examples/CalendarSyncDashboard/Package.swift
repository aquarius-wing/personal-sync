// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CalendarSyncDashboard",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(path: "../../")  // Reference to the main CalendarSync package
    ],
    targets: [
        .target(
            name: "CalendarSyncDashboard",
            dependencies: [
                .product(name: "CalendarSync", package: "swift-sync-system-data")
            ]
        )
    ]
) 