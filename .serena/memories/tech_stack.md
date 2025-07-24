# AIKO Tech Stack

## Platform & Language
- iOS 17.0+ / macOS 13.0+
- Swift 5.9+ with Swift 6 strict concurrency
- Xcode 15.0+ required

## Architecture
- SwiftUI for UI layer
- The Composable Architecture (TCA) for state management
- Actor-based concurrency model
- Clean architecture with platform-specific modules

## Package Structure
- AppCore: Platform-agnostic business logic
- AIKOiOS: iOS-specific implementations
- AIKOmacOS: macOS-specific implementations
- AikoCompat: Sendable-safe wrappers for dependencies
- GraphRAG: LFM2 embedding and tensor operations
- AIKO: Main app target

## Key Dependencies
- swift-composable-architecture: 1.8.0+
- SwiftAnthropic: For Claude API integration
- swift-collections: 1.0.0+
- multipart-kit: 4.5.0+
- ViewInspector: 0.9.0+ (testing)

## iOS Frameworks
- VisionKit: Document scanning
- Core Data: Local storage
- LocalAuthentication: Face ID/Touch ID
- PhotosUI: Photo library access
- AVFoundation: Camera integration