# CalendarSync Development Guide

This document provides comprehensive information for developers working on the CalendarSync Swift package.

## Project Overview

CalendarSync is a Swift package that automatically synchronizes system calendar data to a SQLite database in the background. It provides seamless integration with iOS and macOS calendar systems using EventKit and GRDB.swift for efficient database operations.

## Project Structure

```
swift-sync-system-data/
├── Sources/CalendarSync/           # Main library source code
│   ├── CalendarSync.swift         # Core sync engine (451 lines)
│   ├── CalendarEvent.swift        # Event data model (282 lines)
│   ├── DatabaseManager.swift     # SQLite database operations (346 lines)
│   ├── PersonalSyncConfiguration.swift # Configuration options (137 lines)
│   ├── SyncStatistics.swift      # Sync metrics and stats (54 lines)
│   ├── SyncStatus.swift          # Sync state enum (41 lines)
│   ├── CalendarSync+Exports.swift # Public API exports (14 lines)
│   └── CalendarSync.h            # Objective-C bridge header
├── Demo/                          # Command-line demo application
│   └── main.swift                # Executable demo (141 lines)
├── Tests/CalendarSyncTests/       # Unit and integration tests
│   └── CalendarSyncTests.swift   # Test suite (133 lines)
├── Examples/                      # Complete iOS example projects
│   ├── CalendarSyncDashboard/    # Full iOS app example
│   ├── CalendarSyncDashboard.xcodeproj # Xcode project
│   ├── README.md                 # Examples documentation
├── Example/                       # Code-level usage examples
│   └── CalendarSyncExample.swift # Comprehensive code examples (327 lines)
├── Package.swift                  # Swift Package Manager configuration
├── README.md                     # User documentation
├── LICENSE                       # MIT license
└── .gitignore                    # Git ignore rules
```

## Architecture Components

### Core Library (`Sources/CalendarSync/`)

1. **CalendarSync.swift** - Main synchronization engine
   - Manages EventKit integration
   - Handles automatic sync lifecycle
   - Provides public API interface
   - Implements notification-based real-time sync

2. **DatabaseManager.swift** - SQLite database layer
   - GRDB.swift integration
   - Event CRUD operations
   - Database schema management
   - Transaction handling

3. **CalendarEvent.swift** - Data model
   - Event property mapping
   - EventKit to SQLite conversion
   - Codable implementation

4. **PersonalSyncConfiguration.swift** - Configuration system
   - Customizable sync behavior
   - Performance tuning options
   - Feature toggles

5. **SyncStatistics.swift & SyncStatus.swift** - Monitoring
   - Real-time sync metrics
   - Performance tracking
   - Status reporting

## Requirements

### Development Environment
- **Xcode**: 13.0+ (for iOS development)
- **Swift**: 5.5+ (currently tested with Swift 6.1.2)
- **macOS**: 10.15+ (for development)

### Target Platforms
- **iOS**: 13.0+
- **macOS**: 10.15+

### Dependencies
- **GRDB.swift**: 6.0+ (SQLite ORM)
- **EventKit**: System framework (calendar access)
- **Foundation**: System framework

## Getting Started

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/swift-sync-system-data.git
cd swift-sync-system-data

# Verify Swift version
swift --version
# Should show Swift 5.5+ 

# Resolve dependencies
swift package resolve
```

### 2. Building the Library

```bash
# Build the library
swift build

# Build with optimizations
swift build -c release

# Build specific target
swift build --target CalendarSync
```

### 3. Running Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter CalendarSyncTests
```

### 4. Running the Demo

The demo application showcases basic functionality:

```bash
# Run the command-line demo
swift run CalendarSyncDemo

# Or build and run separately
swift build --target CalendarSyncDemo
./.build/debug/CalendarSyncDemo
```

**Note**: The demo requires calendar permissions. On first run, it will request access to your calendar data.

### 5. Exploring Code Examples

```bash
# View comprehensive usage examples
cat Example/CalendarSyncExample.swift

# The file contains:
# - Basic initialization examples
# - Custom configuration examples  
# - Data querying examples
# - Sync control examples
# - Lifecycle management examples
```

## Working with Examples

### iOS Example App

Located in `Examples/CalendarSyncDashboard/`, this is a complete iOS application demonstrating the library's capabilities.

#### Opening in Xcode
```bash
# Navigate to examples directory
cd Examples/

# Open the Xcode project
open CalendarSyncDashboard.xcodeproj
```

#### Fixing Dependencies (if needed)
```bash
# Run the dependency fix script
cd Examples/
./修复依赖.sh

# Or manually in Xcode:
# File → Swift Packages → Reset Package Caches
```

#### Running the iOS App
1. Open `CalendarSyncDashboard.xcodeproj` in Xcode
2. Select a physical iOS device (simulators cannot access calendar)
3. Build and run (⌘+R)
4. Grant calendar permissions when prompted

## Development Workflow

### Code Style and Standards

1. **Swift Style**: Follow Swift API Design Guidelines
2. **Documentation**: Use Swift DocC comments for public APIs
3. **Error Handling**: Comprehensive error handling with custom error types
4. **Threading**: Main actor for UI updates, background queues for sync operations
5. **Memory Management**: Proper weak references and cleanup

### Adding New Features

1. **Create feature branch**:
   ```bash
   git checkout -b feature/new-feature-name
   ```

2. **Implement in library**:
   - Add code to `Sources/CalendarSync/`
   - Follow existing patterns and architecture
   - Add comprehensive error handling

3. **Add tests**:
   - Update `Tests/CalendarSyncTests/CalendarSyncTests.swift`
   - Test both success and failure cases
   - Mock external dependencies where needed

4. **Update examples**:
   - Add usage examples to `Example/CalendarSyncExample.swift`
   - Update iOS app if relevant
   - Update documentation

5. **Test thoroughly**:
   ```bash
   swift test
   swift run CalendarSyncDemo
   # Test iOS app on device
   ```

### Testing Strategy

#### Unit Tests
```bash
# Run specific test methods
swift test --filter testBasicSync

# Run with coverage (if available)
swift test --enable-code-coverage
```

#### Integration Tests
- Test with real EventKit data
- Test database operations
- Test sync lifecycle

#### Manual Testing
- Use the demo app for quick validation
- Use the iOS example app for UI testing
- Test on both iOS and macOS if applicable

### Debugging

#### Enable Verbose Logging
```swift
let config = PersonalSyncConfiguration(
    enableLogging: true,
    // ... other options
)
```

#### Common Debug Scenarios
1. **Calendar Permission Issues**: Check system settings
2. **Database Errors**: Verify file permissions and disk space
3. **Sync Failures**: Check network and EventKit access
4. **Performance Issues**: Monitor sync statistics

## Release Process

### Version Management

This project follows [Semantic Versioning (SemVer)](https://semver.org/):
- **MAJOR**: Breaking API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Pre-Release Checklist

1. **Code Quality**:
   ```bash
   # Ensure all tests pass
   swift test
   
   # Build release version
   swift build -c release
   
   # Run demo to verify functionality
   swift run CalendarSyncDemo
   ```

2. **Documentation**:
   - Update `README.md` with new features
   - Update API documentation
   - Update example code if needed
   - Verify all links work

3. **Examples**:
   - Test iOS example app on device
   - Verify all example code compiles
   - Update screenshots if UI changed

4. **Performance**:
   - Run performance tests
   - Check memory usage
   - Verify battery impact is minimal

### Creating a Release

1. **Update version in Package.swift** (if needed):
   ```swift
   // Update version in comments or tags
   ```

2. **Create and push tag**:
   ```bash
   # Create annotated tag
   git tag -a v1.0.0 -m "Release version 1.0.0"
   
   # Push tag to repository
   git push origin v1.0.0
   ```

3. **Create GitHub Release**:
   - Go to GitHub repository
   - Click "Releases" → "Create a new release"
   - Select the tag created above
   - Add release notes with:
     - New features
     - Bug fixes
     - Breaking changes (if any)
     - Upgrade instructions (if needed)

4. **Update Package Registries** (if applicable):
   - Swift Package Index will automatically detect new tags
   - Update any other package manager entries

### Release Notes Template

```markdown
## CalendarSync v1.0.0

### New Features
- Added automatic background sync capability
- Improved real-time event monitoring
- Enhanced error handling and recovery

### Bug Fixes
- Fixed memory leak in event processing
- Resolved timezone handling issues
- Improved database transaction reliability

### Breaking Changes
- `CalendarSync.init()` now throws instead of returning optional
- Renamed `SyncConfiguration` to `PersonalSyncConfiguration`

### Upgrade Guide
- Update initialization code to handle thrown errors
- Replace old configuration class name

### Performance Improvements
- 50% faster initial sync
- Reduced memory usage during large syncs
- Optimized database queries
```

## Troubleshooting

### Common Development Issues

1. **Build Failures**:
   ```bash
   # Clean and rebuild
   swift package clean
   swift build
   ```

2. **Dependency Issues**:
   ```bash
   # Reset package cache
   swift package reset
   swift package resolve
   ```

3. **Permission Errors**:
   - Ensure Info.plist contains calendar usage description
   - Check system privacy settings
   - Reset app permissions in iOS Settings

4. **Database Issues**:
   - Check file permissions
   - Verify disk space
   - Check for corrupted database files

### Getting Help

1. **Check existing documentation**: README.md, code comments
3. **Run the demo app**: `swift run CalendarSyncDemo`
4. **Check iOS example**: `Examples/CalendarSyncDashboard/`
5. **Search issues**: GitHub repository issues
6. **Create new issue**: If problem persists

## Contributing

### Pull Request Process

1. Fork the repository
2. Create feature branch from `master`
3. Make changes following code style guidelines
4. Add/update tests for new functionality
5. Update documentation and examples
6. Ensure all tests pass
7. Submit pull request with detailed description

### Code Review Criteria

- Code quality and style consistency
- Comprehensive test coverage
- Documentation completeness
- Performance impact assessment
- Backward compatibility consideration

---

This development guide should provide everything needed to contribute to and maintain the CalendarSync project. For questions or suggestions about this guide, please open an issue in the repository.