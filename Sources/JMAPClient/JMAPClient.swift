//
//  JMAPClient.swift
//  JMAPClient
//

import Foundation

/// HTTP Client protocol for making requests
///
/// This protocol abstracts HTTP networking to allow for testing and different implementations.
public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default URLSession implementation of HTTPClient
public class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}

/// A Swift client for the JMAP (JSON Meta Application Protocol) email protocol
///
/// `JMAPClient` provides a complete implementation of the JMAP protocol for email operations,
/// supporting authentication, mailbox management, email retrieval, and email sending.
/// It follows RFC 8620 (JMAP Core) and RFC 8621 (JMAP Mail) specifications.
///
/// ## Usage
///
/// ```swift
/// let client = JMAPClient(baseURL: URL(string: "https://api.fastmail.com")!)
///
/// // Authenticate with the server
/// let session = try await client.authenticate(with: "your-api-token")
///
/// // Get mailboxes
/// let mailboxes = try await client.getMailboxes()
///
/// // Send an email
/// let submission = try await client.sendEmail(
///     from: JMAPEmailAddress(email: "sender@example.com"),
///     to: [JMAPEmailAddress(email: "recipient@example.com")],
///     subject: "Hello from JMAP",
///     textBody: "This is a test email sent via JMAP"
/// )
/// ```
///
/// ## Features
///
/// - **Authentication**: Bearer token authentication with session management
/// - **Mailboxes**: List, search by role or name, get mailbox information
/// - **Emails**: Retrieve emails with metadata, search and filter capabilities
/// - **Identities**: Manage sender identities for email composition
/// - **Sending**: Compose and send emails with HTML support, CC/BCC recipients
/// - **Error Handling**: Comprehensive error reporting with localized descriptions
///
/// ## Thread Safety
///
/// `JMAPClient` is designed to be used from a single actor/task. While individual
/// operations are async-safe, concurrent access to the same client instance
/// should be coordinated by the caller.
public class JMAPClient {

    // MARK: - Properties

    private let baseURL: URL
    private let httpClient: HTTPClient
    private var authTokenData: NSMutableData?
    private var sessionInfo: JMAPSession?
    private var accountId: String?

    // MARK: - Initialization

    /// Initialize JMAP Client with server URL
    /// - Parameters:
    ///   - baseURL: The base URL of the JMAP server
    ///   - httpClient: HTTPClient to use for requests (defaults to URLSessionHTTPClient)
    public init(baseURL: URL, httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.baseURL = baseURL
        self.httpClient = httpClient
    }

    /// Initialize JMAP Client with server URL and URLSession
    /// - Parameters:
    ///   - baseURL: The base URL of the JMAP server
    ///   - session: URLSession to use for requests (defaults to .shared)
    public convenience init(baseURL: URL, session: URLSession) {
        self.init(baseURL: baseURL, httpClient: URLSessionHTTPClient(session: session))
    }

    // MARK: - Deinitialization

    deinit {
        // Securely clear authentication token from memory
        clearAuthToken()
    }

    // MARK: - Authentication

    /// Authenticate with the JMAP server using a bearer token
    ///
    /// This method establishes a session with the JMAP server and retrieves session information
    /// including capabilities, accounts, and API endpoints.
    ///
    /// - Parameter token: The authentication token (typically an API token from the email provider)
    /// - Returns: JMAP session information containing capabilities, accounts, and server details
    /// - Throws: `JMAPError.authenticationFailed` if the token is invalid or authentication fails
    ///           `JMAPError.invalidResponse` if the server response is malformed
    public func authenticate(with token: String) async throws -> JMAPSession {
        // Clear any existing token first
        clearAuthToken()

        // Create mutable data for secure storage
        if let tokenData = token.data(using: .utf8) {
            self.authTokenData = NSMutableData(data: tokenData)
        }

        let sessionURL = baseURL.appendingPathComponent("jmap/session")
        var request = URLRequest(url: sessionURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JMAPError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw JMAPError.authenticationFailed(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let sessionInfo = try decoder.decode(JMAPSession.self, from: data)
        self.sessionInfo = sessionInfo

        // Set the primary account ID
        if let primaryAccountId = sessionInfo.primaryAccounts[JMAPCapabilities.mail] {
            self.accountId = primaryAccountId
        }

        return sessionInfo

    }

    // MARK: - Core JMAP Methods

    /// Make a JMAP method call
    /// - Parameters:
    ///   - request: The JMAP request to send
    /// - Returns: JMAP response
    /// - Throws: JMAPError if the request fails
    public func makeRequest(_ request: JMAPRequest) async throws -> JMAPResponse {
        guard let authTokenData = authTokenData,
              let authToken = String(data: authTokenData as Data, encoding: .utf8) else {
            throw JMAPError.notAuthenticated
        }

        guard let sessionInfo = sessionInfo else {
            throw JMAPError.notAuthenticated
        }

        guard let apiURL = URL(string: sessionInfo.apiUrl) else {
            throw JMAPError.invalidURL
        }
        var urlRequest = URLRequest(url: apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await httpClient.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JMAPError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw JMAPError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(JMAPResponse.self, from: data)
    }

    // MARK: - Mailbox Operations

    /// Get all mailboxes for the authenticated account
    ///
    /// Retrieves all mailboxes available to the authenticated user, including system mailboxes
    /// (Inbox, Sent, Drafts, Trash) and any custom mailboxes.
    ///
    /// - Returns: Array of JMAP mailboxes sorted by their sort order
    /// - Throws: `JMAPError.notAuthenticated` if not authenticated
    ///           `JMAPError.requestFailed` if the server request fails
    public func getMailboxes() async throws -> [JMAPMailbox] {
        guard let accountId = accountId else {
            throw JMAPError.notAuthenticated
        }

        let methodCall = JMAPMethodCall(
            method: JMAPMethods.mailboxGet,
            arguments: [
                "accountId": accountId
            ],
            clientId: "0"
        )

        let request = JMAPRequest(
            using: [JMAPCapabilities.core, JMAPCapabilities.mail],
            methodCalls: [methodCall]
        )

        let response = try await makeRequest(request)

        guard let methodResponse = response.methodResponses.first,
              let list = methodResponse.response["list"] as? [[String: Any]] else {
            throw JMAPError.invalidResponse
        }

        let data = try JSONSerialization.data(withJSONObject: list)
        let decoder = JSONDecoder()
        return try decoder.decode([JMAPMailbox].self, from: data)
    }

    /// Get a mailbox by its role (e.g., inbox, sent, drafts)
    ///
    /// Searches for a mailbox with the specified system role. This is useful for finding
    /// standard mailboxes like Inbox, Sent Items, Drafts, etc.
    ///
    /// - Parameter role: The mailbox role to search for (e.g., `.inbox`, `.sent`, `.drafts`)
    /// - Returns: The mailbox with the specified role, or nil if not found
    /// - Throws: `JMAPError.notAuthenticated` if not authenticated
    ///           `JMAPError.requestFailed` if the server request fails
    public func getMailbox(byRole role: JMAPMailboxRole) async throws -> JMAPMailbox? {
        let mailboxes = try await getMailboxes()
        return mailboxes.first { $0.role == role }
    }

    /// Get a mailbox by its display name
    ///
    /// Searches for a mailbox with the specified display name. This is useful for finding
    /// custom mailboxes or when you know the exact display name of a mailbox.
    ///
    /// - Parameter name: The display name of the mailbox to search for
    /// - Returns: The mailbox with the specified name, or nil if not found
    /// - Throws: `JMAPError.notAuthenticated` if not authenticated
    ///           `JMAPError.requestFailed` if the server request fails
    public func getMailbox(byName name: String) async throws -> JMAPMailbox? {
        let mailboxes = try await getMailboxes()
        return mailboxes.first { $0.name == name }
    }

    // MARK: - Email Operations

    /// Get emails from a specific mailbox
    ///
    /// Retrieves emails from the specified mailbox, ordered by received date (newest first).
    /// This method returns email metadata including headers, size, and preview text.
    ///
    /// - Parameters:
    ///   - mailboxId: The ID of the mailbox to get emails from
    ///   - limit: Maximum number of emails to retrieve (default: 50, max: 256)
    /// - Returns: Array of emails with full metadata, sorted by received date (newest first)
    /// - Throws: `JMAPError.notAuthenticated` if not authenticated
    ///           `JMAPError.requestFailed` if the server request fails
    public func getEmails(fromMailbox mailboxId: String, limit: Int = 50) async throws -> [JMAPEmail] {
        guard let accountId = accountId else {
            throw JMAPError.notAuthenticated
        }

        // First, query for email IDs
        let queryCall = JMAPMethodCall(
            method: JMAPMethods.emailQuery,
            arguments: [
                "accountId": accountId,
                "filter": [
                    "inMailbox": mailboxId
                ],
                "sort": [
                    [
                        "property": "receivedAt",
                        "isAscending": false
                    ]
                ],
                "limit": limit
            ],
            clientId: "0"
        )

        // Then get the email details
        let getCall = JMAPMethodCall(
            method: JMAPMethods.emailGet,
            arguments: [
                "accountId": accountId,
                "#ids": [
                    "resultOf": "0",
                    "name": "Email/query",
                    "path": "/ids"
                ],
                "properties": [
                    "id", "blobId", "threadId", "mailboxIds", "keywords",
                    "size", "receivedAt", "sentAt", "from", "to", "cc", "bcc",
                    "subject", "preview", "hasAttachment"
                ]
            ],
            clientId: "1"
        )

        let request = JMAPRequest(
            using: [JMAPCapabilities.core, JMAPCapabilities.mail],
            methodCalls: [queryCall, getCall]
        )

        let response = try await makeRequest(request)

        guard response.methodResponses.count >= 2,
              let getResponse = response.methodResponses.last,
              let list = getResponse.response["list"] as? [[String: Any]] else {
            throw JMAPError.invalidResponse
        }

        let data = try JSONSerialization.data(withJSONObject: list)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([JMAPEmail].self, from: data)
    }

    // MARK: - Identity Operations

    /// Get all email identities for the authenticated account
    ///
    /// Retrieves all configured email identities (sender addresses) available to the
    /// authenticated user. These identities can be used as the "from" address when sending emails.
    ///
    /// - Returns: Array of email identities with display names, email addresses, and signatures
    /// - Throws: `JMAPError.notAuthenticated` if not authenticated
    ///           `JMAPError.requestFailed` if the server request fails
    public func getIdentities() async throws -> [JMAPIdentity] {
        guard let accountId = accountId else {
            throw JMAPError.notAuthenticated
        }

        let methodCall = JMAPMethodCall(
            method: JMAPMethods.identityGet,
            arguments: [
                "accountId": accountId
            ],
            clientId: "0"
        )

        let request = JMAPRequest(
            using: [JMAPCapabilities.core, JMAPCapabilities.submission],
            methodCalls: [methodCall]
        )

        let response = try await makeRequest(request)

        guard let methodResponse = response.methodResponses.first,
              let list = methodResponse.response["list"] as? [[String: Any]] else {
            throw JMAPError.invalidResponse
        }

        let data = try JSONSerialization.data(withJSONObject: list)
        let decoder = JSONDecoder()
        return try decoder.decode([JMAPIdentity].self, from: data)
    }

    // MARK: - Email Sending Operations

    /// Send an email through the JMAP server
    ///
    /// Creates and sends an email with the specified recipients and content. The email is first
    /// created as a draft in the drafts mailbox, then submitted for delivery. Upon successful
    /// submission, the draft is automatically deleted.
    ///
    /// - Parameters:
    ///   - from: Sender email address (must match an available identity)
    ///   - to: Array of recipient email addresses
    ///   - subject: Email subject line
    ///   - textBody: Plain text body content
    ///   - htmlBody: Optional HTML body content for rich formatting
    ///   - cc: Optional array of CC recipient email addresses
    ///   - bcc: Optional array of BCC recipient email addresses
    /// - Returns: Email submission details including submission ID and delivery status
    /// - Throws: `JMAPError.notAuthenticated` if not authenticated
    ///           `JMAPError.identityNotFound` if sender address doesn't match any identity
    ///           `JMAPError.mailboxNotFound` if drafts mailbox cannot be found
    ///           `JMAPError.sendingFailed` if email creation or submission fails
    public func sendEmail(
        from: JMAPEmailAddress,
        to: [JMAPEmailAddress],
        subject: String,
        textBody: String,
        htmlBody: String? = nil,
        cc: [JMAPEmailAddress]? = nil,
        bcc: [JMAPEmailAddress]? = nil
    ) async throws -> JMAPEmailSubmission {
        guard let accountId = accountId else {
            throw JMAPError.notAuthenticated
        }

        // Get identities to find the appropriate one
        let identities = try await getIdentities()
        guard let identity = identities.first(where: { $0.email == from.email }) else {
            throw JMAPError.identityNotFound
        }

        // Get drafts mailbox
        guard let draftsMailbox = try await getMailbox(byRole: .drafts) else {
            throw JMAPError.mailboxNotFound
        }

        let emailId = "draft-\(UUID().uuidString)"
        let submissionId = "send-\(UUID().uuidString)"

        // Prepare email body
        var bodyValues: [String: [String: Any]] = [
            "text": [
                "value": textBody,
                "charset": "utf-8"
            ]
        ]

        let textBodyParts: [[String: Any]] = [
            [
                "partId": "text",
                "type": "text/plain"
            ]
        ]

        var htmlBodyParts: [[String: Any]]? = nil

        if let htmlBody = htmlBody {
            bodyValues["html"] = [
                "value": htmlBody,
                "charset": "utf-8"
            ]
            htmlBodyParts = [
                [
                    "partId": "html",
                    "type": "text/html"
                ]
            ]
        }

        // Create email
        var emailData: [String: Any] = [
            "from": [from.toDictionary()],
            "to": to.map { $0.toDictionary() },
            "subject": subject,
            "mailboxIds": [draftsMailbox.id: true],
            "keywords": [JMAPKeywords.draft: true],
            "textBody": textBodyParts,
            "bodyValues": bodyValues
        ]

        if let cc = cc {
            emailData["cc"] = cc.map { $0.toDictionary() }
        }

        if let bcc = bcc {
            emailData["bcc"] = bcc.map { $0.toDictionary() }
        }

        if let htmlBodyParts = htmlBodyParts {
            emailData["htmlBody"] = htmlBodyParts
        }

        // Email/set method call
        let emailSetCall = JMAPMethodCall(
            method: JMAPMethods.emailSet,
            arguments: [
                "accountId": accountId,
                "create": [
                    emailId: emailData
                ]
            ],
            clientId: "0"
        )

        // EmailSubmission/set method call
        let submissionSetCall = JMAPMethodCall(
            method: JMAPMethods.emailSubmissionSet,
            arguments: [
                "accountId": accountId,
                "onSuccessDestroyEmail": ["#\(submissionId)"],
                "create": [
                    submissionId: [
                        "emailId": "#\(emailId)",
                        "identityId": identity.id
                    ]
                ]
            ],
            clientId: "1"
        )

        let request = JMAPRequest(
            using: [JMAPCapabilities.core, JMAPCapabilities.mail, JMAPCapabilities.submission],
            methodCalls: [emailSetCall, submissionSetCall]
        )

        let response = try await makeRequest(request)

        // Check for errors in the response
        guard response.methodResponses.count >= 2 else {
            throw JMAPError.sendingFailed(reason: "Insufficient responses")
        }

        // Check for errors in the first response (Email/set)
        let emailResponse = response.methodResponses[0]
        if let errorType = emailResponse.response["type"] as? String {
            let errorDescription = emailResponse.response["description"] as? String ?? "Unknown error"
            if errorType == "accountReadOnly" {
                throw JMAPError.sendingFailed(reason: "Account is read-only. Please create an API token with write permissions in Fastmail settings.")
            }
            throw JMAPError.sendingFailed(reason: "\(errorType): \(errorDescription)")
        }

        // Check for email creation errors
        if let notCreated = emailResponse.response["notCreated"] as? [String: [String: Any]] {
            for (id, error) in notCreated {
                let errorType = error["type"] as? String ?? "unknown"
                let errorDescription = error["description"] as? String ?? "Unknown error"
                var properties = ""
                if let invalidProps = error["properties"] as? [String] {
                    properties = " (Properties: \(invalidProps.joined(separator: ", ")))"
                }
                throw JMAPError.sendingFailed(reason: "Email creation failed for \(id): \(errorType): \(errorDescription)\(properties)")
            }
        }

        let submissionResponse = response.methodResponses[1]

        // Check for errors in the submission response
        if let errorType = submissionResponse.response["type"] as? String {
            let errorDescription = submissionResponse.response["description"] as? String ?? "Unknown error"
            if errorType == "accountReadOnly" {
                throw JMAPError.sendingFailed(reason: "Account is read-only. Please create an API token with write permissions in Fastmail settings.")
            }
            throw JMAPError.sendingFailed(reason: "\(errorType): \(errorDescription)")
        }

        guard let created = submissionResponse.response["created"] as? [String: [String: Any]] else {
            // Check for errors
            if let notCreated = submissionResponse.response["notCreated"] as? [String: [String: Any]],
               let firstError = notCreated.values.first {
                let errorType = firstError["type"] as? String ?? "unknown"
                let errorDescription = firstError["description"] as? String ?? "Unknown error"
                var properties = ""
                if let invalidProps = firstError["properties"] as? [String] {
                    properties = " (Properties: \(invalidProps.joined(separator: ", ")))"
                }
                throw JMAPError.sendingFailed(reason: "\(errorType): \(errorDescription)\(properties)")
            }
            throw JMAPError.sendingFailed(reason: "Failed to create email submission")
        }

        // Get the first created submission (since we only created one)
        guard let submissionData = created.values.first else {
            throw JMAPError.sendingFailed(reason: "No submission created")
        }

        // Parse the submission response
        let submissionJson = try JSONSerialization.data(withJSONObject: submissionData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(JMAPEmailSubmission.self, from: submissionJson)
    }

    // MARK: - Helper Properties

    /// Current session information
    public var currentSession: JMAPSession? {
        return sessionInfo
    }

    /// Current account ID
    public var currentAccountId: String? {
        return accountId
    }

    /// Whether the client is authenticated
    public var isAuthenticated: Bool {
        return authTokenData != nil && sessionInfo != nil
    }

    /// Securely logout and clear authentication data
    public func logout() {
        clearAuthToken()
        sessionInfo = nil
        accountId = nil
    }

    // MARK: - Private Methods

    private func clearAuthToken() {
        if let tokenData = authTokenData {
            // Securely overwrite the token data with zeros
            memset(tokenData.mutableBytes, 0, tokenData.length)
        }
        authTokenData = nil
    }
}

// MARK: - Helper Extensions

private extension JMAPEmailAddress {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["email": email]
        if let name = name {
            dict["name"] = name
        }
        return dict
    }
}

// MARK: - Error Types

/// JMAP Client errors
public enum JMAPError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case authenticationFailed(statusCode: Int)
    case requestFailed(statusCode: Int)
    case identityNotFound
    case mailboxNotFound
    case sendingFailed(reason: String)
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Client is not authenticated. Please authenticate first."
        case .invalidResponse:
            return "Received invalid response from server."
        case .authenticationFailed(let statusCode):
            return "Authentication failed with status code: \(statusCode)"
        case .requestFailed(let statusCode):
            return "Request failed with status code: \(statusCode)"
        case .identityNotFound:
            return "No matching identity found for the sender email address."
        case .mailboxNotFound:
            return "Required mailbox not found."
        case .sendingFailed(let reason):
            return "Failed to send email: \(reason)"
        case .invalidURL:
            return "Invalid URL received from server."
        }
    }
}
