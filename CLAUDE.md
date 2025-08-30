# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift Package Manager project that provides a complete JMAP (JSON Meta Application Protocol) client implementation. The project consists of two main components:

1. **JMAPClient Library**: A Swift library implementing the JMAP protocol for email operations
2. **swift-jmap-client CLI**: A command-line interface for interacting with JMAP servers

The project follows JMAP RFC 8620 (Core) and RFC 8621 (Mail) specifications and is designed to work with JMAP-compliant email servers like Fastmail.

## Architecture

- **JMAPClient**: Core library providing JMAP protocol implementation
- **swift-jmap-client**: CLI executable using Swift Argument Parser
- **Comprehensive test suite**: Unit tests with mock HTTP client
- **DocC documentation**: Full API documentation support

## Project Structure

```
Sources/
├── JMAPClient/           # Core JMAP library
│   ├── JMAPClient.swift  # Main client implementation
│   └── JMAPTypes.swift   # JMAP data types and protocols
└── swift-jmap-client/   # CLI executable
    └── swift_jmap_client.swift  # Command-line interface

Tests/
└── JMAPClientTests/     # Comprehensive test suite
    └── JMAPClientTests.swift

Package.swift            # Swift Package Manager configuration
```

## Dependencies

- **swift-argument-parser** (1.2.0+): CLI argument parsing and subcommands
- **swift-docc-plugin** (1.1.0+): Documentation generation support

## Development Commands

### Build
- `swift build` - Build the project in debug mode
- `swift build -c release` - Build optimized release version
- `swift build --show-bin-path` - Show the path to built binaries

### Test
- `swift test` - Run all unit tests
- `swift test --list-tests` - List available tests
- `swift test --enable-code-coverage` - Run tests with code coverage
- `swift test --filter <pattern>` - Run specific tests matching pattern

### Run CLI
- `swift run swift-jmap-client --help` - Show all available commands
- `swift run swift-jmap-client auth --help` - Show authentication command help

### Documentation
- `swift package generate-documentation` - Generate DocC documentation
- `swift package preview-documentation` - Preview documentation locally

### Package Management
- `swift package resolve` - Resolve and fetch dependencies
- `swift package update` - Update dependencies to latest versions
- `swift package show-dependencies` - Display dependency graph
- `swift package clean` - Clean build artifacts

## CLI Usage Examples

### Authentication
```bash
swift run swift-jmap-client auth \
  --server "https://api.fastmail.com" \
  --token "your-api-token"
```

### List Mailboxes
```bash
swift run swift-jmap-client mailbox list \
  --server "https://api.fastmail.com" \
  --token "your-api-token"
```

### Send Email
```bash
swift run swift-jmap-client send \
  --server "https://api.fastmail.com" \
  --token "your-api-token" \
  --from "sender@example.com" \
  --to "recipient@example.com" \
  --subject "Test Email" \
  --body "Hello from Swift JMAP Client!"
```

### List Recent Emails
```bash
swift run swift-jmap-client email list \
  --server "https://api.fastmail.com" \
  --token "your-api-token" \
  --mailbox inbox \
  --limit 10
```

## Library Integration

The JMAPClient library can be integrated into Swift applications:

```swift
import JMAPClient

let client = JMAPClient(baseURL: URL(string: "https://api.fastmail.com")!)
let session = try await client.authenticate(with: "your-token")
let mailboxes = try await client.getMailboxes()
```

## Key Features

### JMAP Client Library
- ✅ Session authentication and management
- ✅ Mailbox operations (list, get by role/name)
- ✅ Email operations (list, query)
- ✅ Identity management
- ✅ Email composition and sending
- ✅ Full JMAP protocol compliance
- ✅ Async/await support
- ✅ Comprehensive error handling

### CLI Tool
- ✅ Interactive command-line interface
- ✅ Authentication testing
- ✅ Mailbox management
- ✅ Email sending with HTML support
- ✅ Identity listing
- ✅ Comprehensive help system

### Testing
- ✅ Unit tests with mock HTTP client
- ✅ Authentication flow testing
- ✅ Email operations testing
- ✅ Error handling validation

## Platform Support

- macOS 13.0+
- iOS 16.0+
- tvOS 16.0+
- watchOS 9.0+

## JMAP Protocol References

- [JMAP Core Specification (RFC 8620)](https://tools.ietf.org/html/rfc8620)
- [JMAP Mail Extension (RFC 8621)](https://tools.ietf.org/html/rfc8621)
- [JMAP Server Information](https://jmap.io/server.html)

## Development Notes

- Uses Swift 6.2+ with strict concurrency enabled
- Follows Swift API design guidelines
- Comprehensive DocC documentation
- Full async/await support throughout
- Proper error handling with localized descriptions
- Memory-safe with modern Swift practices
