// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "QuashSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "QuashSDK",
            targets: ["QuashSDK"]
        )
    ],
    dependencies: [
        .package(
            name: "Firebase",
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            .upToNextMajor(from: "10.0.0")
        )
    ],
    targets: [
        .target(
            name: "QuashSDK",
            dependencies: [
                .product(name: "FirebaseCrashlytics", package: "Firebase"),
                .product(name: "FirebaseAnalytics", package: "Firebase")
            ],
            path: "QuashSDK/QuashSDK/Classes",
            resources: [
                .process("../Assets")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
