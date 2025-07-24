# AIKO Development Commands

## Environment Setup
```bash
# Clone repository
git clone https://github.com/JoshMcDev/AIKO.git
cd aiko

# Install dependencies
swift package resolve

# Open in Xcode
open AIKO.xcodeproj
```

## Development Workflow
```bash
# Create new feature branch
git checkout -b feature/feature-name

# Update dependencies
swift package update

# Generate Xcode project (if needed)
swift package generate-xcodeproj

# Run specific target
swift run AIKO

# Debug build
swift build -c debug

# Release build
swift build -c release
```

## Testing and Debugging
```bash
# Run tests with coverage
swift test --enable-code-coverage

# View test results
open .build/debug/codecov/lcov.info

# Run tests in parallel
swift test --parallel

# Run with verbose output
swift test --verbose

# Debug specific test
swift test --filter TestClassName/testMethodName
```

## Common Development Tasks
```bash
# Find TODO comments
grep -r "TODO" Sources/

# Find files by name
find . -name "*.swift" | grep -i "scanner"

# Check file differences
git diff filename

# View recent commits
git log --oneline -10

# Search in codebase
grep -r "pattern" Sources/ --include="*.swift"
```

## Xcode Build Commands
```bash
# List available schemes
xcodebuild -list

# Build for specific device
xcodebuild -scheme AIKO -destination "platform=iOS Simulator,name=iPhone 16 Pro"

# Clean build folder
xcodebuild clean

# Run on physical device
xcodebuild -scheme AIKO -destination "platform=iOS,name=My iPhone"
```