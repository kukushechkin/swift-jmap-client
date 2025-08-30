#!/bin/bash
#
# Swift JMAP Client - Example Usage
#
# This script demonstrates comprehensive usage of the Swift JMAP client CLI tool
# for interacting with JMAP-compliant email servers (tested with Fastmail).
#
# Usage:
#   # Run with environment variables (recommended):
#   API_TOKEN="your-token" FROM_EMAIL="you@example.com" ./example.sh
#
#   # Run with all settings:
#   SERVER_URL="https://api.fastmail.com" \
#   API_TOKEN="your-token" \
#   FROM_EMAIL="sender@example.com" \
#   TO_EMAIL="recipient@example.com" \
#   ./example.sh
#
#   # Or edit the default values below and run:
#   ./example.sh
#
# Requirements:
# 1. Valid API token with read/write permissions
# 2. Swift installed and available in PATH
# 3. Build the project first: swift build -c release
#

set -e # Exit on any error

# =============================================================================
# Configuration - Override with environment variables
# =============================================================================

# These can be overridden with environment variables:
# SERVER_URL="https://api.fastmail.com" ./example.sh
# API_TOKEN="your-token" FROM_EMAIL="you@example.com" ./example.sh

SERVER_URL="${SERVER_URL:-https://api.fastmail.com}"
API_TOKEN="${API_TOKEN:-your-api-token-here}"
FROM_EMAIL="${FROM_EMAIL:-your-email@example.com}"
TO_EMAIL="${TO_EMAIL:-recipient@example.com}"

# =============================================================================
# Helper Functions
# =============================================================================

print_section() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

run_command() {
    echo "🔧 Running: $1"
    echo
    eval "$1"
    echo
}

# =============================================================================
# Main Script
# =============================================================================

echo "🚀 Swift JMAP Client - Comprehensive Example"
echo "=============================================="
echo
echo "📋 Configuration:"
echo "   Server: $SERVER_URL"
echo "   From: $FROM_EMAIL"
echo "   To: $TO_EMAIL"
echo "   Token: ${API_TOKEN:0:20}... (truncated)"
echo
echo "💡 Tip: Override these with environment variables:"
echo "   SERVER_URL=\"https://your-server.com\" API_TOKEN=\"your-token\" ./example.sh"

# Check if the binary exists
if ! command -v swift &>/dev/null; then
    echo "❌ Swift not found. Please install Swift or ensure it's in your PATH."
    exit 1
fi

# Check if required configuration is provided
if [[ "$API_TOKEN" == "your-api-token-here" ]]; then
    echo "❌ Please provide a valid API token:"
    echo "   API_TOKEN=\"your-actual-token\" ./example.sh"
    echo "   or edit the API_TOKEN variable in this script"
    exit 1
fi

if [[ "$FROM_EMAIL" == "your-email@example.com" ]]; then
    echo "❌ Please provide a valid from email address:"
    echo "   FROM_EMAIL=\"you@example.com\" ./example.sh"
    echo "   or edit the FROM_EMAIL variable in this script"
    exit 1
fi

print_section "1. 🔐 Authentication Testing"
echo "Testing server connectivity and token validity..."
run_command "swift run swift-jmap-client auth --server '$SERVER_URL' --token '$API_TOKEN'"

print_section "2. 📫 Mailbox Management"
echo "Listing all available mailboxes..."
run_command "swift run swift-jmap-client mailbox list --server '$SERVER_URL' --token '$API_TOKEN'"

echo "Getting specific mailbox information..."
run_command "swift run swift-jmap-client mailbox get --server '$SERVER_URL' --token '$API_TOKEN' --role inbox"
run_command "swift run swift-jmap-client mailbox get --server '$SERVER_URL' --token '$API_TOKEN' --role sent"
run_command "swift run swift-jmap-client mailbox get --server '$SERVER_URL' --token '$API_TOKEN' --role drafts"

print_section "3. 📧 Email Operations"
echo "Listing recent emails from inbox..."
run_command "swift run swift-jmap-client email list --server '$SERVER_URL' --token '$API_TOKEN' --mailbox inbox --limit 5"

echo "Listing emails from sent folder..."
run_command "swift run swift-jmap-client email list --server '$SERVER_URL' --token '$API_TOKEN' --mailbox sent --limit 3"

print_section "4. 👤 Identity Management"
echo "Listing available sender identities..."
run_command "swift run swift-jmap-client identity list --server '$SERVER_URL' --token '$API_TOKEN'"

print_section "5. 📤 Email Sending"
echo "Sending a comprehensive test email..."

# Create a timestamp for unique subject
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

run_command "swift run swift-jmap-client send \\
    --server '$SERVER_URL' \\
    --token '$API_TOKEN' \\
    --from '$FROM_EMAIL' \\
    --to '$TO_EMAIL' \\
    --subject 'Swift JMAP Client Test - $TIMESTAMP' \\
    --body 'Hello from Swift JMAP Client!

This test email was sent on $TIMESTAMP using the Swift JMAP client CLI tool.

✅ Features Successfully Tested:
• Server authentication and session management
• Mailbox listing and information retrieval
• Email querying and metadata extraction
• Identity management and validation
• Email composition and delivery

🔧 Technical Details:
• Protocol: JMAP (RFC 8620 Core, RFC 8621 Mail)
• Implementation: Swift with async/await
• Server: $SERVER_URL
• Authentication: Bearer token

Thank you for testing the Swift JMAP Client!

Best regards,
The Swift JMAP Client Team' \\
    --html-body '<html>
<head>
    <meta charset=\"UTF-8\">
    <title>Swift JMAP Client Test</title>
</head>
<body style=\"font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; color: #333;\">
    <h1 style=\"color: #007AFF;\">🚀 Swift JMAP Client Test</h1>

    <p>This test email was sent on <strong>$TIMESTAMP</strong> using the Swift JMAP client CLI tool.</p>

    <h2 style=\"color: #34C759;\">✅ Features Successfully Tested:</h2>
    <ul>
        <li>Server authentication and session management</li>
        <li>Mailbox listing and information retrieval</li>
        <li>Email querying and metadata extraction</li>
        <li>Identity management and validation</li>
        <li>Email composition and delivery</li>
    </ul>

    <h2 style=\"color: #FF9500;\">🔧 Technical Details:</h2>
    <table style=\"border-collapse: collapse; width: 100%;\">
        <tr><td style=\"padding: 8px; border: 1px solid #ddd; font-weight: bold;\">Protocol:</td><td style=\"padding: 8px; border: 1px solid #ddd;\">JMAP (RFC 8620 Core, RFC 8621 Mail)</td></tr>
        <tr><td style=\"padding: 8px; border: 1px solid #ddd; font-weight: bold;\">Implementation:</td><td style=\"padding: 8px; border: 1px solid #ddd;\">Swift with async/await</td></tr>
        <tr><td style=\"padding: 8px; border: 1px solid #ddd; font-weight: bold;\">Server:</td><td style=\"padding: 8px; border: 1px solid #ddd;\">$SERVER_URL</td></tr>
        <tr><td style=\"padding: 8px; border: 1px solid #ddd; font-weight: bold;\">Authentication:</td><td style=\"padding: 8px; border: 1px solid #ddd;\">Bearer token</td></tr>
    </table>

    <p style=\"margin-top: 30px;\">Thank you for testing the Swift JMAP Client!</p>

    <p style=\"color: #666; font-style: italic;\">Best regards,<br>The Swift JMAP Client Team</p>
</body>
</html>'"

print_section "6. ✅ Completion Summary"
echo "All Swift JMAP Client operations completed successfully!"
echo
echo "🎯 What was tested:"
echo "   ✓ Server authentication and session establishment"
echo "   ✓ Mailbox discovery and metadata retrieval"
echo "   ✓ Email listing and filtering capabilities"
echo "   ✓ Identity management and sender validation"
echo "   ✓ Email composition, sending, and delivery tracking"
echo
echo "💡 Next Steps:"
echo "   • Integrate JMAPClient library into your Swift applications"
echo "   • Explore advanced JMAP features like email filtering and search"
echo "   • Set up automated email workflows using the CLI tool"
echo "   • Contribute to the project at: https://github.com/your-repo/swift-jmap-client"
echo
echo "📚 Documentation:"
echo "   • Run 'swift run swift-jmap-client --help' for command reference"
echo "   • Generate API docs with 'swift package generate-documentation'"
echo "   • View JMAP specification at https://jmap.io"
echo
echo "🌟 Running This Script With Your Own Settings:"
echo "   # Quick one-liner with your credentials:"
echo "   API_TOKEN=\"fmu1-xxx\" FROM_EMAIL=\"you@example.com\" ./example.sh"
echo
echo "   # Full configuration:"
echo "   SERVER_URL=\"https://api.fastmail.com\" \\"
echo "   API_TOKEN=\"your-token-here\" \\"
echo "   FROM_EMAIL=\"sender@yourdomain.com\" \\"
echo "   TO_EMAIL=\"recipient@example.com\" \\"
echo "   ./example.sh"
echo
echo "   # Test with a different server:"
echo "   SERVER_URL=\"https://jmap.example.com\" API_TOKEN=\"your-token\" ./example.sh"
echo
echo "🔧 Individual CLI Usage Examples:"
echo "   swift run swift-jmap-client auth --help"
echo "   swift run swift-jmap-client mailbox --help"
echo "   swift run swift-jmap-client email --help"
echo "   swift run swift-jmap-client send --help"
echo "   swift run swift-jmap-client identity --help"
