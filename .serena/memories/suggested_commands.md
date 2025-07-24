# AIKO Suggested Shell Commands

## Essential Build Commands
```bash
# Primary build command (always use this for iOS builds)
cd /Users/J/aiko && xcodebuild -scheme AIKO -destination "platform=iOS Simulator,name=iPhone 16 Pro" -skipPackagePluginValidation build 2>&1 | grep -E "(error:|warning:)"

# Quick Swift build check
swift build

# Full test suite
swift test
```

## Code Quality Validation
```bash
# Check SwiftLint violations
swiftlint

# Auto-fix SwiftLint issues
swiftlint --fix

# Format code
swiftformat .

# Combined quality check
swiftlint && swiftformat . && swift build
```

## macOS System Commands (Darwin)
```bash
# List files with details
ls -la

# Find files
find . -name "*.swift" -type f

# Search in files
grep -r "pattern" . --include="*.swift"

# View file content
cat filename.swift

# Check disk usage
du -sh *

# Process management
ps aux | grep swift
killall swift-frontend

# Open in Finder
open .

# Copy files
cp -r source destination

# Move/rename
mv oldname newname
```

## Git Operations
```bash
# Current status
git status

# View changes
git diff

# Stage and commit
git add . && git commit -m "feat: description"

# Push to current branch (newfeet)
git push origin newfeet

# Pull latest changes
git pull origin newfeet

# Create new branch
git checkout -b feature/name

# View commit history
git log --oneline -20
```

## Quick Validation Workflow
```bash
# Complete validation before committing
cd /Users/J/aiko && \
swiftlint && \
swiftformat . && \
swift build && \
swift test && \
echo "✅ All checks passed!"
```

## Common Development Patterns
```bash
# Find implementation of a feature
grep -r "FeatureName" Sources/ --include="*.swift"

# Check for TODOs
grep -r "TODO\|FIXME" Sources/ --include="*.swift"

# View recent changes to a file
git log -p -3 filename.swift

# Compare branches
git diff main..newfeet

# Clean and rebuild
swift package clean && swift build
```

## Performance and Debugging
```bash
# Build with optimization
swift build -c release

# Run with environment variables
SWIFT_DETERMINISTIC_HASHING=1 swift test

# Check binary size
du -sh .build/release/AIKO

# Find large files
find . -type f -size +1M -exec ls -lh {} \;
```

## IMPORTANT: Always use the primary xcodebuild command for iOS builds!