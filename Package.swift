// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExpenseManager",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ExpenseManager",
            targets: ["ExpenseManager"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ExpenseManager",
            dependencies: [],
            path: "ExpenseManager",
            exclude: [
                "Tests",
                "Info.plist",
                "ExpenseManager.entitlements",
                "PrivacyInfo.xcprivacy"
            ]
        ),
        .testTarget(
            name: "ExpenseManagerTests",
            dependencies: ["ExpenseManager"],
            path: "ExpenseManager/Tests"
        )
    ]
)
