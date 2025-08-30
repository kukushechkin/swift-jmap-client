# Swift JMAP Client

A comprehensive Swift implementation of the JMAP (JSON Meta Application Protocol) for email operations, providing both a reusable library and a command-line interface.

[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Features

### 🚀 JMAP Library
- ✅ **Full JMAP Protocol Support** - RFC 8620 (Core) and RFC 8621 (Mail)
- ✅ **Session Management** - Authentication and capability discovery
- ✅ **Mailbox Operations** - List, search by role/name, metadata retrieval
- ✅ **Email Management** - Retrieve, query, and manage emails
- ✅ **Identity Management** - Handle sender identities and signatures
- ✅ **Email Sending** - Compose and send emails with HTML support
- ✅ **Async/Await** - Modern Swift concurrency throughout
- ✅ **Comprehensive Error Handling** - Detailed error reporting
- ✅ **DocC Documentation** - Complete API documentation

### 🖥️ Command-Line Interface
- ✅ **Interactive CLI** - Full-featured command-line tool
- ✅ **Authentication Testing** - Verify server connectivity and tokens
- ✅ **Mailbox Management** - List and inspect mailboxes
- ✅ **Email Operations** - List, search, and view emails
- ✅ **Email Sending** - Send emails with rich formatting
- ✅ **Batch Operations** - Scriptable for automation

### 🔧 Developer Experience
- ✅ **Comprehensive Tests** - Unit tests with mock HTTP client
- ✅ **Example Scripts** - Ready-to-use examples
- ✅ **Swift Package Manager** - Easy integration
- ✅ **Cross-Platform** - macOS, iOS, tvOS, watchOS support

## Quick Start

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kukushechkin/swift-jmap-client.git", from: "0.2")
]
```

### Library Usage

```swift
import JMAPClient

// Initialize client
let client = JMAPClient(baseURL: URL(string: "https://api.fastmail.com")!)

// Authenticate
let session = try await client.authenticate(with: "your-api-token")

// Get mailboxes
let mailboxes = try await client.getMailboxes()
let inbox = try await client.getMailbox(byRole: .inbox)

// List recent emails
if let inbox = inbox {
    let emails = try await client.getEmails(fromMailbox: inbox.id, limit: 10)
    for email in emails {
        print("\(email.subject ?? "No Subject") - \(email.from?.first?.email ?? "Unknown")")
    }
}

// Send an email
let submission = try await client.sendEmail(
    from: JMAPEmailAddress(email: "sender@example.com"),
    to: [JMAPEmailAddress(email: "recipient@example.com")],
    subject: "Hello from Swift JMAP!",
    textBody: "This email was sent using the Swift JMAP client.",
    htmlBody: "<p>This email was sent using the <strong>Swift JMAP client</strong>.</p>"
)
```

### CLI Usage

Build and use the command-line tool:

```bash
# Build the project
swift build -c release

# Test authentication
swift run swift-jmap-client auth \
  --server "https://api.fastmail.com" \
  --token "your-api-token"

# List mailboxes
swift run swift-jmap-client mailbox list \
  --server "https://api.fastmail.com" \
  --token "your-api-token"

# Send an email
swift run swift-jmap-client send \
  --server "https://api.fastmail.com" \
  --token "your-api-token" \
  --from "sender@example.com" \
  --to "recipient@example.com" \
  --subject "Test Email" \
  --body "Hello from the CLI!"
```

## CLI Commands

| Command | Description | Example |
|---------|-------------|---------|
| `auth` | Test authentication and show session info | `swift run swift-jmap-client auth --server <url> --token <token>` |
| `mailbox list` | List all mailboxes | `swift run swift-jmap-client mailbox list --server <url> --token <token>` |
| `mailbox get` | Get specific mailbox by role or name | `swift run swift-jmap-client mailbox get --role inbox` |
| `email list` | List emails from a mailbox | `swift run swift-jmap-client email list --mailbox inbox --limit 5` |
| `send` | Send an email | `swift run swift-jmap-client send --from <email> --to <email> --subject <subject> --body <body>` |
| `identity list` | List sender identities | `swift run swift-jmap-client identity list --server <url> --token <token>` |

Use `--help` with any command for detailed options.

## Supported JMAP Servers

This client has been tested with:
- ✅ **Fastmail** - Full support for all features
- ⚠️ **Other JMAP servers** - Should work but may need testing

## API Token Setup

### Fastmail
1. Go to Settings → Privacy & Security → API Tokens
2. Create a new token with these scopes:
   - ✅ Read mail
   - ✅ Write mail
   - ✅ Send mail
3. Copy the token for use with the client

### Other Providers
Consult your email provider's documentation for API token creation.

## Development

### Requirements
- Swift 6.2+
- macOS 13+ (for development)

### Building
```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test

# Generate documentation
swift package generate-documentation --target JMAPClient

# Run example script
./example.sh
```

### Project Structure
```
swift-jmap-client/
├── Sources/
│   ├── JMAPClient/           # Core library
│   │   ├── JMAPClient.swift  # Main client implementation
│   │   └── JMAPTypes.swift   # JMAP data types
│   └── swift-jmap-client/    # CLI executable
│       └── swift_jmap_client.swift
├── Tests/
│   └── JMAPClientTests/      # Comprehensive test suite
├── Package.swift             # Swift Package Manager config
├── example.sh               # Usage examples
└── README.md               # This file
```

### Testing
The project includes comprehensive unit tests with a mock HTTP client:

```bash
swift test                              # Run all tests
swift test --enable-code-coverage       # Run with coverage
swift test --filter JMAPClientTests     # Run specific test suite
```

## Documentation

### API Documentation
Generate comprehensive API documentation:
```bash
swift package generate-documentation --target JMAPClient
```

### Example Scripts
Run the included example script to see all features:
```bash
# Run with your credentials (recommended):
API_TOKEN="your-token" FROM_EMAIL="you@example.com" ./example.sh

# Run with full configuration:
SERVER_URL="https://api.fastmail.com" \
API_TOKEN="your-token" \
FROM_EMAIL="sender@example.com" \
TO_EMAIL="recipient@example.com" \
./example.sh

# Or edit the defaults in example.sh and run:
./example.sh
```

## JMAP Protocol Support

This implementation follows these specifications:
- [RFC 8620 - JMAP Core](https://tools.ietf.org/html/rfc8620)
- [RFC 8621 - JMAP Mail](https://tools.ietf.org/html/rfc8621)

### Supported JMAP Methods
- ✅ Session authentication (`/jmap/session`)
- ✅ `Mailbox/get`
- ✅ `Email/query`
- ✅ `Email/get`
- ✅ `Email/set` (creation)
- ✅ `EmailSubmission/set`
- ✅ `Identity/get`

## Error Handling

The library provides comprehensive error handling:

```swift
do {
    let emails = try await client.getEmails(fromMailbox: "inbox", limit: 10)
} catch JMAPError.notAuthenticated {
    print("Please authenticate first")
} catch JMAPError.requestFailed(let statusCode) {
    print("Request failed with status: \(statusCode)")
} catch JMAPError.sendingFailed(let reason) {
    print("Failed to send email: \(reason)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Performance Considerations

- The client maintains a single session per instance
- HTTP requests are made using `URLSession` with proper async/await
- Large email lists are paginated (default limit: 50, max: 256)
- Email bodies are loaded on-demand to optimize memory usage

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Run the test suite (`swift test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Swift and Swift Package Manager
- Follows JMAP specifications from the IETF
- Inspired by the need for a modern, Swift-native JMAP client
- Thanks to Fastmail for their excellent JMAP implementation and documentation

## Support

- 📚 [API Documentation](https://your-username.github.io/swift-jmap-client/documentation/jmapclient/)
- 🐛 [Issue Tracker](https://github.com/your-username/swift-jmap-client/issues)
- 💬 [Discussions](https://github.com/your-username/swift-jmap-client/discussions)
- 📖 [JMAP Specification](https://jmap.io)

---

Made with ❤️ in Swift
