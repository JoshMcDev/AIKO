# AIKO Task Completion Commands

## Build and Test Commands
```bash
# Build the project
swift build

# Run all tests
swift test

# Run specific test suite
swift test --filter DocumentImageProcessorTests

# Build for iOS Simulator
xcodebuild -scheme AIKO -destination "platform=iOS Simulator,name=iPhone 16 Pro" -skipPackagePluginValidation build

# Clean build
swift package clean
swift build
```

## Code Quality Commands
```bash
# Run SwiftLint
swiftlint

# Fix SwiftLint violations automatically
swiftlint --fix

# Run SwiftFormat
swiftformat .

# Check for compilation errors
swift build 2>&1 | grep -E "(error:|warning:)"
```

## Git Commands
```bash
# Check status
git status

# Add all changes
git add .

# Commit with message
git commit -m "Message"

# Push to branch
git push origin branch-name

# Current branch: newfeet
```

## Performance Testing
```bash
# Run performance tests
swift test --filter PerformanceTests

# Memory profiling (use Xcode Instruments)
```

## When Task is Complete
1. Run full test suite: `swift test`
2. Check SwiftLint: `swiftlint`
3. Format code: `swiftformat .`
4. Build validation: `swift build`
5. Commit changes with descriptive message
6. Update relevant documentation
7. Create summary markdown file as specified