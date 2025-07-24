// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIKO",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AIKO", targets: ["AIKO"]),
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "AIKOiOS", targets: ["AIKOiOS"]),
        .library(name: "AIKOmacOS", targets: ["AIKOmacOS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.8.0"),
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/vapor/multipart-kit", from: "4.5.0"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0"),
    ],
    targets: [
        // MARK: - Compatibility Module for Non-Sendable Dependencies

        .target(
            name: "AikoCompat",
            dependencies: [
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
            ],
            path: "Sources/AikoCompat",
            exclude: ["README.md"],
            swiftSettings: [
                // Swift 6 strict concurrency enabled - provides Sendable-safe wrappers
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),

        // MARK: - Shared Core Module (Platform-Agnostic)

        .target(
            name: "AppCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AikoCompat", // Use our Sendable-safe wrapper instead of SwiftAnthropic directly
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "Sources/AppCore",
            exclude: ["README.md"],
            swiftSettings: [
                // Swift 6 strict concurrency enabled for platform-agnostic core
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),

        // MARK: - iOS Platform Module

        .target(
            name: "AIKOiOS",
            dependencies: [
                "AppCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/AIKOiOS",
            exclude: ["README.md", "Service-Concurrency-Guide.md"],
            swiftSettings: [
                // Swift 6 strict concurrency enabled for iOS platform
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),

        // MARK: - macOS Platform Module

        .target(
            name: "AIKOmacOS",
            dependencies: [
                "AppCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/AIKOmacOS",
            exclude: ["README.md"],
            swiftSettings: [
                // Swift 6 strict concurrency enabled for macOS platform
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),

        // MARK: - GraphRAG Module (LFM2 Embedding and Tensor Operations)

        .target(
            name: "GraphRAG",
            dependencies: [
                "AppCore",
            ],
            path: "Sources/GraphRAG",
            swiftSettings: [
                // Swift 6 strict concurrency enabled for GraphRAG module
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),

        // MARK: - Main App Target (Orchestrates Platform Modules)

        .target(
            name: "AIKO",
            dependencies: [
                "AppCore",
                "GraphRAG",
                .target(name: "AIKOiOS", condition: .when(platforms: [.iOS])),
                .target(name: "AIKOmacOS", condition: .when(platforms: [.macOS])),
                .product(name: "MultipartKit", package: "multipart-kit"),
            ],
            path: "Sources",
            exclude: [
                "AppCore", // Exclude AppCore subdirectory
                "AIKOiOS", // Exclude AIKOiOS subdirectory
                "AIKOmacOS", // Exclude AIKOmacOS subdirectory
                "AikoCompat", // Exclude AikoCompat subdirectory
                "GraphRAG", // Exclude GraphRAG subdirectory
                "Models/CoreData/FORM_MIGRATION_GUIDE.md",
                "Resources/Clauses/clauseSelectionEngine.ts",
                "Resources/Clauses/ClauseSelectionEngine.md",
                "Resources/Clauses/ClauseDatabase.json",
                "Resources/Clauses/ClauseSelection_QuickReference.md",
                "AIKOiOS/Service-Concurrency-Guide.md", // Exclude documentation file
                "Services/ConfidenceBasedAutoFillEnhanced.swift.disabled", // Exclude disabled file
            ],
            resources: [
                .copy("Resources/DFTemplates"),
                .copy("Resources/Templates"),
                .copy("Models/AIKO.xcdatamodeld"),
                .copy("Models/MetricsModel.xcdatamodeld"),
                .copy("Models/AIKO_Updated.xcdatamodeld"),
                .process("Resources/AppIcon.png"),
                .process("Resources/SAMIcon.png"),
                // .copy("Resources/LFM2-700M-Unsloth-XL-GraphRAG.mlmodel"), // Removed - 700MB model causing build hang
                .copy("Resources/Forms/SF1449_Form.md"),
                .copy("Resources/Forms/SF33_Form.md"),
                .copy("Resources/Forms/SF30_Form.md"),
                .copy("Resources/Forms/SF18_Form.md"),
                .copy("Resources/Forms/SF26_Form.md"),
                .copy("Resources/Forms/SF44_Form.md"),
                .copy("Resources/Forms/DD1155_Form.md"),
            ],
            swiftSettings: [
                // Swift 6 strict concurrency enabled - actor boundaries properly established
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),

        // MARK: - Test Targets

        .testTarget(
            name: "AppCoreTests",
            dependencies: [
                "AppCore",
                "AIKO",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Tests/AppCoreTests"
        ),
        .testTarget(
            name: "AIKOiOSTests",
            dependencies: [
                .target(name: "AIKOiOS", condition: .when(platforms: [.iOS])),
                "AppCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ViewInspector", package: "ViewInspector"),
            ],
            path: "Tests/AIKOiOSTests"
        ),
        .testTarget(
            name: "AIKOmacOSTests",
            dependencies: [
                .target(name: "AIKOmacOS", condition: .when(platforms: [.macOS])),
                "AppCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Tests/AIKOmacOSTests"
        ),
        .testTarget(
            name: "GraphRAGTests",
            dependencies: [
                "GraphRAG",
                "AppCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Tests/GraphRAGTests"
        ),
        .testTarget(
            name: "AIKOTests",
            dependencies: ["AppCore"],
            path: "Tests",
            exclude: [
                "README.md",
                "Test_Documentation",
                "OCRValidation",
                "AppCoreTests",
                "AIKOiOSTests",
                "AIKOmacOSTests",
                "GraphRAGTests", // Exclude GraphRAGTests subdirectory
                // "Shared", // Re-enabled for proper test utilities
                // Keep remaining tests that haven't been migrated yet
                "Integration",
                "Performance",
                "Security",
                "Services",
                "Templates",
                "TestRunners",
                "UI",
                "Unit",
            ]
        ),
    ]
)
