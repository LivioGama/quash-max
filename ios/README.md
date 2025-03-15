# Official iOS SDK for [Quash](https://quashbugs.com/)

Welcome to the Quash iOS SDK, your ultimate in-app bug reporting tool! Built by developers for developers, this SDK
captures everything you need to start fixing issues right away. It records crash logs, session replays, network logs,
device information, and much more, ensuring you have all the details at your fingertips.

<p align="center">
    <a href="https://quash.io/docs/ios-sdk/">
        <img src="https://storage.googleapis.com/misc_quash_static/ios-sdk-png.png"/>
    </a>
</p>

<p align="center">
    <a href="https://img.shields.io/badge/iOS-13.0%2B-blue"><img alt="iOS" src="https://img.shields.io/badge/iOS-13.0%2B-blue"/></a>
    <a href="https://github.com/Oscorp-HQ/quash-ios-sdk/releases"><img src="https://img.shields.io/github/v/release/Oscorp-HQ/quash-ios-sdk" /></a>
</p>

## Features

- Crash Logs: Automatically capture and log crashes in your application
- Session Replays: Record user sessions to understand the steps leading to an issue
- Network Logs: Capture all network requests and responses
- Device Information: Collect detailed device information including OS version, device model, and more
- Customizable Bug Reports: Allow users to report issues with custom fields and attachments

## Table of Contents

1. [Setup](#setup)
    - [Swift Package Manager](#swift-package-manager)
    - [CocoaPods](#cocoapods)
2. [Installation](#installation)
3. [SDK Initialization](#sdk-initialization)
4. [Network Request Interception](#network-request-interception)
5. [Activation Mechanics](#activation-mechanics)
6. [Firebase Integration](#firebase-integration)
7. [Contributing](#contributing)

## Setup

### Swift Package Manager

Add the package dependency to your Xcode project:

1. In Xcode, select File > Add Packages
2. Enter the package URL: https://github.com/Oscorp-HQ/quash-ios-sdk
3. Select the version you want to use

Or add it to your Package.swift:

```swift
dependencies: [
    .package(url: 'https://github.com/Oscorp-HQ/quash-ios-sdk', from: '1.0.0')
]
```

### CocoaPods

Add the following to your Podfile:

```ruby
pod 'QuashSDK', '~> 1.0'
```

Then run:

```bash
pod install
```

## Installation

### Requirements

- iOS 13.0+
- Xcode 14+
- Swift 5.5+

### Dependencies

The Quash SDK has the following dependencies:

```swift
dependencies: [
    .package(url: 'https://github.com/firebase/firebase-ios-sdk', from: '10.0.0')
]
```

## SDK Initialization

Initialize the SDK in your AppDelegate or SceneDelegate:

```swift
import QuashSDK

Quash.initialize(
    applicationKey: 'YOUR_APPLICATION_KEY',
    enableNetworkLogging: true,
    sessionLength: 40,
    useExistingFirebase: false
)
```

**Parameters:**

- **Application Key**: Your unique application identifier
- **Network Logging**: Enable to capture all network traffic
- **Session Length**: Maximum duration of session recordings in seconds
- **Use Existing Firebase**: Set to true if you're already using Firebase in your app

## Network Request Interception

Quash uses URLProtocol to automatically intercept and log network requests. No additional setup required if network
logging is enabled during initialization.

For custom URLSession configurations:

```swift
let config = URLSessionConfiguration.default
config.protocolClasses = [QuashURLProtocol.self] + (config.protocolClasses ?? [])
let session = URLSession(configuration: config)
```

## Activation Mechanics

The SDK is activated by shaking the device, which presents the bug reporting interface. You can customize this behavior:

```swift
Quash.shared.configure {
    $0.activationGesture = .shake
    $0.activationThreshold = 2.0
}
```

## Firebase Integration

1. Add your Firebase configuration file:
    - Download `GoogleService-Info.plist` from Firebase Console
    - Add it to your Xcode project
    - Ensure it's included in your target

2. Initialize Firebase if not using existing instance:

```swift
Quash.initialize(
    applicationKey: 'YOUR_APPLICATION_KEY',
    useExistingFirebase: false
)
```

## Key Differences from Android SDK

1. **User Interface**: Uses SwiftUI instead of XML layouts for modern, native iOS UI components
2. **Network Logging**: Uses URLProtocol instead of OkHttp interceptors for request/response capture
3. **Threading Model**: Uses GCD (Grand Central Dispatch) instead of Coroutines for concurrency
4. **Firebase Integration**: Uses Firebase iOS SDK with plist configuration instead of JSON
5. **Permission Handling**: Uses iOS-specific permission APIs (PHPhotoLibrary, etc.)

## Contributing

We love contributions! Please read our
[contribution guidelines](/CONTRIBUTING.md) to get started.
