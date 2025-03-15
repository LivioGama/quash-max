// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ios-example",
    platforms: [
        .iOS(.v13)
    ],
    dependencies: [
        .package(name: "QuashSDK", path: "../ios"),
        .package(
            name: "Firebase",
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            .upToNextMajor(from: "10.21.0")
        )
    ],
    targets: [
        .target(
            name: "ios-example",
            dependencies: [
                .product(name: "QuashSDK", package: "QuashSDK"),
                .product(name: "FirebaseCrashlytics", package: "Firebase"),
                .product(name: "FirebaseAnalytics", package: "Firebase")
            ],
            path: "ios-example"
        )
    ]
) 