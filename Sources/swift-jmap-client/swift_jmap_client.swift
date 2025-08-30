//
//  swift_jmap_client.swift
//  swift-jmap-client
//

import ArgumentParser
import Foundation
import JMAPClient

@main
struct SwiftJMAPClient: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-jmap-client",
        abstract: "A Swift JMAP client for interacting with JMAP mail servers",
        version: "1.0.0",
        subcommands: [
            AuthCommand.self,
            MailboxCommand.self,
            EmailCommand.self,
            SendCommand.self,
            IdentityCommand.self
        ]
    )
}

// MARK: - Authentication Command

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Authenticate with a JMAP server and display session information"
    )

    @Option(name: .shortAndLong, help: "JMAP server URL")
    var server: String

    @Option(name: .shortAndLong, help: "Authentication token")
    var token: String

    mutating func run() async throws {
        guard let url = URL(string: server) else {
            print("Error: Invalid server URL")
            throw ExitCode.validationFailure
        }

        let client = JMAPClient(baseURL: url)

        do {
            let session = try await client.authenticate(with: token)
            print("✅ Authentication successful!")
            print("\nSession Information:")
            print("Username: \(session.username)")
            print("API URL: \(session.apiUrl)")
            print("State: \(session.state)")

            print("\nCapabilities:")
            for (capability, _) in session.capabilities {
                print("  - \(capability)")
            }

            print("\nAccounts:")
            for (accountId, account) in session.accounts {
                print("  \(accountId): \(account.name) (Personal: \(account.isPersonal))")
            }
        } catch {
            print("❌ Authentication failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Mailbox Commands

struct MailboxCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mailbox",
        abstract: "Mailbox operations",
        subcommands: [
            MailboxListCommand.self,
            MailboxGetCommand.self
        ]
    )
}

struct MailboxListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all mailboxes"
    )

    @Option(name: .shortAndLong, help: "JMAP server URL")
    var server: String

    @Option(name: .shortAndLong, help: "Authentication token")
    var token: String

    mutating func run() async throws {
        let client = try await authenticateClient(server: server, token: token)

        do {
            let mailboxes = try await client.getMailboxes()
            print("📫 Mailboxes (\(mailboxes.count)):")
            print()

            for mailbox in mailboxes.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let roleDisplay = mailbox.role?.rawValue.capitalized ?? "Custom"
                let unreadDisplay = mailbox.unreadEmails > 0 ? " (\(mailbox.unreadEmails) unread)" : ""
                print("  \(mailbox.name) [\(roleDisplay)]")
                print("    ID: \(mailbox.id)")
                print("    Emails: \(mailbox.totalEmails)\(unreadDisplay)")
                print("    Threads: \(mailbox.totalThreads)")
                print()
            }
        } catch {
            print("❌ Failed to get mailboxes: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct MailboxGetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get mailbox by name or role"
    )

    @Option(name: .shortAndLong, help: "JMAP server URL")
    var server: String

    @Option(name: .shortAndLong, help: "Authentication token")
    var token: String

    @Option(name: .shortAndLong, help: "Mailbox name")
    var name: String?

    @Option(name: .shortAndLong, help: "Mailbox role (inbox, sent, drafts, trash, etc.)")
    var role: String?

    mutating func run() async throws {
        guard name != nil || role != nil else {
            print("Error: Either --name or --role must be specified")
            throw ExitCode.validationFailure
        }

        let client = try await authenticateClient(server: server, token: token)

        do {
            let mailbox: JMAPMailbox?

            if let name = name {
                mailbox = try await client.getMailbox(byName: name)
            } else if let roleString = role, let mailboxRole = JMAPMailboxRole(rawValue: roleString.lowercased()) {
                mailbox = try await client.getMailbox(byRole: mailboxRole)
            } else {
                print("Error: Invalid role. Valid roles: \(JMAPMailboxRole.allCases.map { $0.rawValue }.joined(separator: ", "))")
                throw ExitCode.validationFailure
            }

            if let mailbox = mailbox {
                print("📫 Mailbox Found:")
                print("  Name: \(mailbox.name)")
                print("  ID: \(mailbox.id)")
                print("  Role: \(mailbox.role?.rawValue ?? "none")")
                print("  Total Emails: \(mailbox.totalEmails)")
                print("  Unread Emails: \(mailbox.unreadEmails)")
                print("  Total Threads: \(mailbox.totalThreads)")
                print("  Unread Threads: \(mailbox.unreadThreads)")
            } else {
                print("❌ Mailbox not found")
                throw ExitCode.failure
            }
        } catch {
            print("❌ Failed to get mailbox: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Email Commands

struct EmailCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "email",
        abstract: "Email operations",
        subcommands: [
            EmailListCommand.self
        ]
    )
}

struct EmailListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List emails from a mailbox"
    )

    @Option(name: .shortAndLong, help: "JMAP server URL")
    var server: String

    @Option(name: .shortAndLong, help: "Authentication token")
    var token: String

    @Option(name: .shortAndLong, help: "Mailbox name or role")
    var mailbox: String = "inbox"

    @Option(name: .shortAndLong, help: "Number of emails to retrieve")
    var limit: Int = 10

    mutating func run() async throws {
        let client = try await authenticateClient(server: server, token: token)

        do {
            // Try to find mailbox by role first, then by name
            var targetMailbox: JMAPMailbox?

            if let role = JMAPMailboxRole(rawValue: mailbox.lowercased()) {
                targetMailbox = try await client.getMailbox(byRole: role)
            }

            if targetMailbox == nil {
                targetMailbox = try await client.getMailbox(byName: mailbox)
            }

            guard let mailbox = targetMailbox else {
                print("❌ Mailbox '\(self.mailbox)' not found")
                throw ExitCode.failure
            }

            let emails = try await client.getEmails(fromMailbox: mailbox.id, limit: limit)

            print("📧 Emails in \(mailbox.name) (\(emails.count)):")
            print()

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short

            for (index, email) in emails.enumerated() {
                print("[\(index + 1)] \(email.subject ?? "(No Subject)")")

                if let from = email.from?.first {
                    let fromDisplay = from.name ?? from.email
                    print("    From: \(fromDisplay)")
                }

                print("    Date: \(dateFormatter.string(from: email.receivedAt))")
                print("    Size: \(email.size) bytes")

                if let preview = email.preview {
                    let truncatedPreview = String(preview.prefix(100))
                    print("    Preview: \(truncatedPreview)...")
                }

                print("    ID: \(email.id)")
                print()
            }
        } catch {
            print("❌ Failed to get emails: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Send Command

struct SendCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send an email"
    )

    @Option(name: [.customShort("u"), .customLong("server")], help: "JMAP server URL")
    var server: String

    @Option(name: .shortAndLong, help: "Authentication token")
    var token: String

    @Option(name: .shortAndLong, help: "Sender email address")
    var from: String

    @Option(name: [.customShort("r"), .customLong("to")], help: "Recipient email address(es), comma-separated")
    var to: String

    @Option(name: .shortAndLong, help: "Email subject")
    var subject: String

    @Option(name: [.customShort("b"), .customLong("body")], help: "Email body (plain text)")
    var body: String

    @Option(name: [.customShort("c"), .customLong("cc")], help: "CC recipients, comma-separated")
    var cc: String?

    @Option(name: [.customLong("bcc")], help: "BCC recipients, comma-separated")
    var bcc: String?

    @Option(name: [.customLong("html-body")], help: "HTML body content")
    var htmlBody: String?

    mutating func run() async throws {
        let client = try await authenticateClient(server: server, token: token)

        do {
            let fromAddress = JMAPEmailAddress(email: from)
            let toAddresses = to.split(separator: ",").map { JMAPEmailAddress(email: String($0).trimmingCharacters(in: .whitespaces)) }

            var ccAddresses: [JMAPEmailAddress]?
            if let cc = cc {
                ccAddresses = cc.split(separator: ",").map { JMAPEmailAddress(email: String($0).trimmingCharacters(in: .whitespaces)) }
            }

            var bccAddresses: [JMAPEmailAddress]?
            if let bcc = bcc {
                bccAddresses = bcc.split(separator: ",").map { JMAPEmailAddress(email: String($0).trimmingCharacters(in: .whitespaces)) }
            }

            print("📤 Sending email...")
            print("  From: \(from)")
            print("  To: \(to)")
            if let cc = cc { print("  CC: \(cc)") }
            if let bcc = bcc { print("  BCC: \(bcc)") }
            print("  Subject: \(subject)")
            print()

            let submission = try await client.sendEmail(
                from: fromAddress,
                to: toAddresses,
                subject: subject,
                textBody: body,
                htmlBody: htmlBody,
                cc: ccAddresses,
                bcc: bccAddresses
            )

            print("✅ Email sent successfully!")
            print("  Submission ID: \(submission.id)")
            print("  Status: \(submission.undoStatus.rawValue)")

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            print("  Send Time: \(dateFormatter.string(from: submission.sendAt))")

        } catch {
            print("❌ Failed to send email: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Identity Commands

struct IdentityCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "identity",
        abstract: "Identity operations",
        subcommands: [
            IdentityListCommand.self
        ]
    )
}

struct IdentityListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all identities"
    )

    @Option(name: .shortAndLong, help: "JMAP server URL")
    var server: String

    @Option(name: .shortAndLong, help: "Authentication token")
    var token: String

    mutating func run() async throws {
        let client = try await authenticateClient(server: server, token: token)

        do {
            let identities = try await client.getIdentities()
            print("👤 Identities (\(identities.count)):")
            print()

            for identity in identities {
                print("  \(identity.name) <\(identity.email)>")
                print("    ID: \(identity.id)")
                if let textSignature = identity.textSignature {
                    print("    Signature: \(textSignature)")
                }
                print("    May Delete: \(identity.mayDelete)")
                print()
            }
        } catch {
            print("❌ Failed to get identities: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}



// MARK: - Helper Functions

private func authenticateClient(server: String, token: String) async throws -> JMAPClient {
    guard let url = URL(string: server) else {
        print("Error: Invalid server URL")
        throw ExitCode.validationFailure
    }

    let client = JMAPClient(baseURL: url)

    do {
        _ = try await client.authenticate(with: token)
        return client
    } catch {
        print("❌ Authentication failed: \(error.localizedDescription)")
        throw ExitCode.failure
    }
}
