# AIKO Code Style and Conventions

## Swift Code Style
- SwiftLint enforced: 0 violations tolerance
- SwiftFormat for consistent formatting
- Swift 6 strict concurrency compliance

## Architecture Patterns
- TCA (The Composable Architecture) patterns strictly followed
- @ObservableState for TCA feature state
- Hierarchical action enums for feature actions
- Effect handling with async/await
- @Dependency injection for services

## Concurrency
- Actor isolation for thread safety
- @MainActor for UI updates
- Sendable protocol conformance for data types
- AsyncStream for real-time updates

## Naming Conventions
- Features: [Name]Feature (e.g., DocumentScannerFeature)
- Actors: [Name]Engine or [Name]Service (e.g., SessionEngine)
- Clients: [Name]Client (e.g., DocumentScannerClient)
- States: [Name]State with @ObservableState
- Actions: Hierarchical enums with descriptive cases

## Testing
- TCA TestStore for reducer testing
- ViewInspector for SwiftUI view testing
- >90% test coverage target for new code
- Integration tests for complete workflows

## Documentation
- Comprehensive inline documentation
- Public API documentation required
- README files for complex modules