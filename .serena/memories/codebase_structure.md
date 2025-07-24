# AIKO Codebase Structure

## Root Directory
```
aiko/
├── Sources/                # Main source code
├── Tests/                  # Test suites
├── Documentation/          # Project documentation
├── Scripts/               # Build and utility scripts
├── Resources/             # Assets and resources
└── Package.swift          # Swift Package Manager configuration
```

## Sources Directory Structure
```
Sources/
├── AppCore/               # Platform-agnostic business logic
│   ├── Features/         # TCA feature reducers
│   ├── Models/           # Domain models
│   ├── Services/         # Business logic services
│   └── Clients/          # Client protocols
├── AIKOiOS/              # iOS-specific implementations
│   ├── Services/         # iOS service implementations
│   ├── Dependencies/     # iOS dependency implementations
│   └── Views/            # iOS-specific UI views
├── AIKOmacOS/            # macOS-specific implementations
├── AikoCompat/           # Sendable-safe wrappers
├── GraphRAG/             # LFM2 embedding module
├── Models/               # Core Data models
├── Resources/            # App resources
│   ├── Templates/        # Document templates
│   ├── Forms/           # Form definitions
│   └── LFM2 models/     # ML models
└── Views/                # Shared UI components
```

## Key Feature Locations
- Document Scanner: `Sources/AppCore/Features/DocumentScanner/`
- Form Auto-Population: `Sources/AppCore/Features/FormAutoPopulation/`
- Progress Tracking: `Sources/AppCore/Services/ProgressTracking/`
- Media Management: `Sources/AppCore/Clients/MediaManagementClients.swift`

## Test Structure
```
Tests/
├── AppCoreTests/         # Core business logic tests
├── AIKOiOSTests/         # iOS-specific tests
├── AIKOmacOSTests/       # macOS-specific tests
└── GraphRAGTests/        # GraphRAG module tests
```