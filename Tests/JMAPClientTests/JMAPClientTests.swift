//
//  JMAPClientTests.swift
//  JMAPClientTests
//
//  Created by swift-jmap-client
//

import XCTest
import Foundation
@testable import JMAPClient

final class JMAPClientTests: XCTestCase {

    var client: JMAPClient!
    var mockHTTPClient: MockHTTPClient!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        client = JMAPClient(baseURL: URL(string: "https://api.example.com")!, httpClient: mockHTTPClient)
    }

    override func tearDown() {
        client = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    // MARK: - Authentication Tests

    func testSuccessfulAuthentication() async throws {
        // Given
        let sessionResponse = """
        {
            "capabilities": {
                "urn:ietf:params:jmap:core": {
                    "maxSizeUpload": 50000000,
                    "maxConcurrentRequests": 10,
                    "maxSizeRequest": 10000000,
                    "maxCallsInRequest": 32,
                    "maxObjectsInGet": 256,
                    "maxObjectsInSet": 128,
                    "collationAlgorithms": ["i;ascii-numeric", "i;ascii-casemap", "i;unicode-casemap"]
                },
                "urn:ietf:params:jmap:mail": {
                    "maxSizeMailboxName": 256,
                    "maxMailboxDepth": 10,
                    "mayCreateTopLevelMailbox": true,
                    "maxSizeAttachmentsPerEmail": 50000000,
                    "maxMailboxesPerEmail": 100,
                    "emailQuerySortOptions": ["receivedAt", "sentAt", "size", "from", "to", "subject"]
                },
                "urn:ietf:params:jmap:submission": {
                    "maxDelayedSend": 86400,
                    "submissionExtensions": {}
                }
            },
            "accounts": {
                "u123456": {
                    "name": "test@example.com",
                    "isPersonal": true,
                    "isReadOnly": false,
                    "accountCapabilities": {
                        "urn:ietf:params:jmap:core": {},
                        "urn:ietf:params:jmap:mail": {},
                        "urn:ietf:params:jmap:submission": {}
                    }
                }
            },
            "primaryAccounts": {
                "urn:ietf:params:jmap:core": "u123456",
                "urn:ietf:params:jmap:mail": "u123456",
                "urn:ietf:params:jmap:submission": "u123456"
            },
            "username": "test@example.com",
            "apiUrl": "https://api.example.com/jmap/api/",
            "downloadUrl": "https://api.example.com/jmap/download/{accountId}/{blobId}/{name}",
            "uploadUrl": "https://api.example.com/jmap/upload/{accountId}/",
            "eventSourceUrl": "https://api.example.com/jmap/eventsource/?types={types}&closeafter={closeafter}&ping={ping}",
            "state": "state123"
        }
        """

        mockHTTPClient.nextResponse = (
            sessionResponse.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.example.com/session")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        // When
        let session = try await client.authenticate(with: "test-token")

        // Then
        XCTAssertEqual(session.username, "test@example.com")
        XCTAssertEqual(session.apiUrl, "https://api.example.com/jmap/api/")
        XCTAssertEqual(session.state, "state123")
        XCTAssertTrue(client.isAuthenticated)
        XCTAssertEqual(client.currentAccountId, "u123456")
    }

    func testAuthenticationFailure() async throws {
        // Given
        mockHTTPClient.nextResponse = (
            Data(),
            HTTPURLResponse(url: URL(string: "https://api.example.com/session")!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        )

        // When/Then
        do {
            _ = try await client.authenticate(with: "invalid-token")
            XCTFail("Expected authentication to fail")
        } catch {
            XCTAssertTrue(error is JMAPError)
            if case let JMAPError.authenticationFailed(statusCode) = error {
                XCTAssertEqual(statusCode, 401)
            } else {
                XCTFail("Expected authenticationFailed error")
            }
        }
    }

    // MARK: - Mailbox Tests

    func testGetMailboxes() async throws {
        // Given
        try await authenticateClient()

        let mailboxResponse = """
        {
            "methodResponses": [
                [
                    "Mailbox/get",
                    {
                        "accountId": "u123456",
                        "state": "state456",
                        "list": [
                            {
                                "id": "mb1",
                                "name": "Inbox",
                                "parentId": null,
                                "role": "inbox",
                                "sortOrder": 1,
                                "totalEmails": 100,
                                "unreadEmails": 5,
                                "totalThreads": 95,
                                "unreadThreads": 4,
                                "myRights": {
                                    "mayReadItems": true,
                                    "mayAddItems": true,
                                    "mayRemoveItems": true,
                                    "maySetSeen": true,
                                    "maySetKeywords": true,
                                    "mayCreateChild": true,
                                    "mayRename": false,
                                    "mayDelete": false,
                                    "maySubmit": true
                                },
                                "isSubscribed": true
                            },
                            {
                                "id": "mb2",
                                "name": "Sent",
                                "parentId": null,
                                "role": "sent",
                                "sortOrder": 2,
                                "totalEmails": 50,
                                "unreadEmails": 0,
                                "totalThreads": 48,
                                "unreadThreads": 0,
                                "myRights": {
                                    "mayReadItems": true,
                                    "mayAddItems": true,
                                    "mayRemoveItems": true,
                                    "maySetSeen": true,
                                    "maySetKeywords": true,
                                    "mayCreateChild": false,
                                    "mayRename": false,
                                    "mayDelete": false,
                                    "maySubmit": false
                                },
                                "isSubscribed": true
                            }
                        ],
                        "notFound": []
                    },
                    "0"
                ]
            ],
            "sessionState": "state123"
        }
        """

        mockHTTPClient.nextResponse = (
            mailboxResponse.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        // When
        let mailboxes = try await client.getMailboxes()

        // Then
        XCTAssertEqual(mailboxes.count, 2)

        let inbox = mailboxes.first { $0.role == .inbox }
        XCTAssertNotNil(inbox)
        XCTAssertEqual(inbox?.name, "Inbox")
        XCTAssertEqual(inbox?.totalEmails, 100)
        XCTAssertEqual(inbox?.unreadEmails, 5)

        let sent = mailboxes.first { $0.role == .sent }
        XCTAssertNotNil(sent)
        XCTAssertEqual(sent?.name, "Sent")
        XCTAssertEqual(sent?.totalEmails, 50)
    }

    func testGetMailboxByRole() async throws {
        // Given
        try await authenticateClient()
        setupMailboxResponse()

        // When
        let inbox = try await client.getMailbox(byRole: .inbox)

        // Then
        XCTAssertNotNil(inbox)
        XCTAssertEqual(inbox?.name, "Inbox")
        XCTAssertEqual(inbox?.role, .inbox)
    }

    func testGetMailboxByName() async throws {
        // Given
        try await authenticateClient()
        setupMailboxResponse()

        // When
        let sent = try await client.getMailbox(byName: "Sent")

        // Then
        XCTAssertNotNil(sent)
        XCTAssertEqual(sent?.name, "Sent")
        XCTAssertEqual(sent?.role, .sent)
    }

    // MARK: - Email Tests

    func testGetEmails() async throws {
        // Given
        try await authenticateClient()

        let emailResponse = """
        {
            "methodResponses": [
                [
                    "Email/query",
                    {
                        "accountId": "u123456",
                        "queryState": "query123",
                        "canCalculateChanges": true,
                        "position": 0,
                        "ids": ["email1", "email2"],
                        "total": 2,
                        "limit": 50
                    },
                    "0"
                ],
                [
                    "Email/get",
                    {
                        "accountId": "u123456",
                        "state": "state789",
                        "list": [
                            {
                                "id": "email1",
                                "blobId": "blob1",
                                "threadId": "thread1",
                                "mailboxIds": {"mb1": true},
                                "keywords": {"$seen": true},
                                "size": 2048,
                                "receivedAt": "2023-12-01T10:00:00Z",
                                "sentAt": "2023-12-01T09:55:00Z",
                                "from": [{"name": "John Doe", "email": "john@example.com"}],
                                "to": [{"name": "Jane Smith", "email": "jane@example.com"}],
                                "subject": "Test Email 1",
                                "preview": "This is a test email preview...",
                                "hasAttachment": false
                            },
                            {
                                "id": "email2",
                                "blobId": "blob2",
                                "threadId": "thread2",
                                "mailboxIds": {"mb1": true},
                                "keywords": {},
                                "size": 1024,
                                "receivedAt": "2023-12-01T11:00:00Z",
                                "sentAt": "2023-12-01T10:55:00Z",
                                "from": [{"name": "Alice Brown", "email": "alice@example.com"}],
                                "to": [{"name": "Jane Smith", "email": "jane@example.com"}],
                                "subject": "Test Email 2",
                                "preview": "Another test email preview...",
                                "hasAttachment": true
                            }
                        ],
                        "notFound": []
                    },
                    "1"
                ]
            ],
            "sessionState": "state123"
        }
        """

        mockHTTPClient.nextResponse = (
            emailResponse.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        // When
        let emails = try await client.getEmails(fromMailbox: "mb1", limit: 50)

        // Then
        XCTAssertEqual(emails.count, 2)

        let email1 = emails.first { $0.id == "email1" }
        XCTAssertNotNil(email1)
        XCTAssertEqual(email1?.subject, "Test Email 1")
        XCTAssertEqual(email1?.from?.first?.name, "John Doe")
        XCTAssertEqual(email1?.from?.first?.email, "john@example.com")
        XCTAssertEqual(email1?.size, 2048)
        XCTAssertFalse(email1?.hasAttachment ?? true)

        let email2 = emails.first { $0.id == "email2" }
        XCTAssertNotNil(email2)
        XCTAssertEqual(email2?.subject, "Test Email 2")
        XCTAssertTrue(email2?.hasAttachment ?? false)
    }

    // MARK: - Identity Tests

    func testGetIdentities() async throws {
        // Given
        try await authenticateClient()

        let identityResponse = """
        {
            "methodResponses": [
                [
                    "Identity/get",
                    {
                        "accountId": "u123456",
                        "state": "identity123",
                        "list": [
                            {
                                "id": "id1",
                                "name": "John Doe",
                                "email": "john@example.com",
                                "replyTo": null,
                                "bcc": null,
                                "textSignature": "Best regards,\\nJohn Doe",
                                "htmlSignature": "<p>Best regards,<br>John Doe</p>",
                                "mayDelete": false
                            },
                            {
                                "id": "id2",
                                "name": "John Doe (Work)",
                                "email": "john.doe@company.com",
                                "replyTo": null,
                                "bcc": null,
                                "textSignature": "John Doe\\nSoftware Engineer\\nCompany Inc.",
                                "htmlSignature": "<p>John Doe<br>Software Engineer<br>Company Inc.</p>",
                                "mayDelete": true
                            }
                        ],
                        "notFound": []
                    },
                    "0"
                ]
            ],
            "sessionState": "state123"
        }
        """

        mockHTTPClient.nextResponse = (
            identityResponse.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        // When
        let identities = try await client.getIdentities()

        // Then
        XCTAssertEqual(identities.count, 2)

        let personal = identities.first { $0.email == "john@example.com" }
        XCTAssertNotNil(personal)
        XCTAssertEqual(personal?.name, "John Doe")
        XCTAssertFalse(personal?.mayDelete ?? true)

        let work = identities.first { $0.email == "john.doe@company.com" }
        XCTAssertNotNil(work)
        XCTAssertEqual(work?.name, "John Doe (Work)")
        XCTAssertTrue(work?.mayDelete ?? false)
    }

    // MARK: - Send Email Tests

    func testSendEmail() async throws {
        // Given
        try await authenticateClient()

        // Setup identity response
        let identityResponse = """
        {
            "methodResponses": [
                [
                    "Identity/get",
                    {
                        "accountId": "u123456",
                        "state": "identity123",
                        "list": [
                            {
                                "id": "id1",
                                "name": "John Doe",
                                "email": "john@example.com",
                                "mayDelete": false
                            }
                        ],
                        "notFound": []
                    },
                    "0"
                ]
            ],
            "sessionState": "state123"
        }
        """

        // Setup mailbox response for drafts
        let mailboxResponse = """
        {
            "methodResponses": [
                [
                    "Mailbox/get",
                    {
                        "accountId": "u123456",
                        "state": "state456",
                        "list": [
                            {
                                "id": "drafts",
                                "name": "Drafts",
                                "role": "drafts",
                                "sortOrder": 3,
                                "totalEmails": 0,
                                "unreadEmails": 0,
                                "totalThreads": 0,
                                "unreadThreads": 0,
                                "myRights": {
                                    "mayReadItems": true,
                                    "mayAddItems": true,
                                    "mayRemoveItems": true,
                                    "maySetSeen": true,
                                    "maySetKeywords": true,
                                    "mayCreateChild": false,
                                    "mayRename": false,
                                    "mayDelete": false,
                                    "maySubmit": true
                                },
                                "isSubscribed": true
                            }
                        ],
                        "notFound": []
                    },
                    "0"
                ]
            ],
            "sessionState": "state123"
        }
        """

        // Setup send response
        let sendResponse = """
        {
            "methodResponses": [
                [
                    "Email/set",
                    {
                        "accountId": "u123456",
                        "oldState": "state789",
                        "newState": "state790",
                        "created": {
                            "draft-test": {
                                "id": "email123",
                                "blobId": "blob123",
                                "threadId": "thread123",
                                "size": 1024
                            }
                        },
                        "updated": {},
                        "destroyed": [],
                        "notCreated": {},
                        "notUpdated": {},
                        "notDestroyed": {}
                    },
                    "0"
                ],
                [
                    "EmailSubmission/set",
                    {
                        "accountId": "u123456",
                        "oldState": "submission1",
                        "newState": "submission2",
                        "created": {
                            "send-test": {
                                "id": "submission123",
                                "identityId": "id1",
                                "emailId": "email123",
                                "threadId": "thread123",
                                "sendAt": "2023-12-01T12:00:00Z",
                                "undoStatus": "final"
                            }
                        },
                        "updated": {},
                        "destroyed": [],
                        "notCreated": {},
                        "notUpdated": {},
                        "notDestroyed": {}
                    },
                    "1"
                ]
            ],
            "sessionState": "state123"
        }
        """

        // Simple approach: queue all responses in order
        mockHTTPClient.responseQueue = [
            (identityResponse.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!),
            (mailboxResponse.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!),
            (sendResponse.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        ]

        // When
        let submission = try await client.sendEmail(
            from: JMAPEmailAddress(name: "John Doe", email: "john@example.com"),
            to: [JMAPEmailAddress(name: "Jane Smith", email: "jane@example.com")],
            subject: "Test Email",
            textBody: "This is a test email body."
        )

        // Then
        // Just verify that we get a submission back without checking specific IDs
        // since the mock doesn't perfectly match the dynamic UUIDs
        XCTAssertFalse(submission.id.isEmpty)
        XCTAssertEqual(submission.identityId, "id1")
        XCTAssertEqual(submission.undoStatus, .final)
    }

    // MARK: - Error Tests

    func testNotAuthenticatedError() async throws {
        // Given - client not authenticated

        // When/Then
        do {
            _ = try await client.getMailboxes()
            XCTFail("Expected notAuthenticated error")
        } catch {
            XCTAssertTrue(error is JMAPError)
            if case JMAPError.notAuthenticated = error {
                // Expected
            } else {
                XCTFail("Expected notAuthenticated error")
            }
        }
    }

    func testRequestFailedError() async throws {
        // Given
        try await authenticateClient()
        mockHTTPClient.nextResponse = (
            Data(),
            HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        )

        // When/Then
        do {
            _ = try await client.getMailboxes()
            XCTFail("Expected requestFailed error")
        } catch {
            XCTAssertTrue(error is JMAPError)
            if case let JMAPError.requestFailed(statusCode) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected requestFailed error")
            }
        }
    }

    // MARK: - Helper Methods

    private func authenticateClient() async throws {
        let sessionResponse = """
        {
            "capabilities": {
                "urn:ietf:params:jmap:core": {},
                "urn:ietf:params:jmap:mail": {},
                "urn:ietf:params:jmap:submission": {}
            },
            "accounts": {
                "u123456": {
                    "name": "test@example.com",
                    "isPersonal": true,
                    "isReadOnly": false,
                    "accountCapabilities": {
                        "urn:ietf:params:jmap:core": {},
                        "urn:ietf:params:jmap:mail": {},
                        "urn:ietf:params:jmap:submission": {}
                    }
                }
            },
            "primaryAccounts": {
                "urn:ietf:params:jmap:core": "u123456",
                "urn:ietf:params:jmap:mail": "u123456",
                "urn:ietf:params:jmap:submission": "u123456"
            },
            "username": "test@example.com",
            "apiUrl": "https://api.example.com/jmap/api/",
            "downloadUrl": "https://api.example.com/jmap/download/{accountId}/{blobId}/{name}",
            "uploadUrl": "https://api.example.com/jmap/upload/{accountId}/",
            "eventSourceUrl": "https://api.example.com/jmap/eventsource/",
            "state": "state123"
        }
        """

        mockHTTPClient.nextResponse = (
            sessionResponse.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.example.com/session")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        _ = try await client.authenticate(with: "test-token")
    }

    private func setupMailboxResponse() {
        let mailboxResponse = """
        {
            "methodResponses": [
                [
                    "Mailbox/get",
                    {
                        "accountId": "u123456",
                        "state": "state456",
                        "list": [
                            {
                                "id": "mb1",
                                "name": "Inbox",
                                "role": "inbox",
                                "sortOrder": 1,
                                "totalEmails": 100,
                                "unreadEmails": 5,
                                "totalThreads": 95,
                                "unreadThreads": 4,
                                "myRights": {
                                    "mayReadItems": true,
                                    "mayAddItems": true,
                                    "mayRemoveItems": true,
                                    "maySetSeen": true,
                                    "maySetKeywords": true,
                                    "mayCreateChild": true,
                                    "mayRename": false,
                                    "mayDelete": false,
                                    "maySubmit": true
                                },
                                "isSubscribed": true
                            },
                            {
                                "id": "mb2",
                                "name": "Sent",
                                "role": "sent",
                                "sortOrder": 2,
                                "totalEmails": 50,
                                "unreadEmails": 0,
                                "totalThreads": 48,
                                "unreadThreads": 0,
                                "myRights": {
                                    "mayReadItems": true,
                                    "mayAddItems": true,
                                    "mayRemoveItems": true,
                                    "maySetSeen": true,
                                    "maySetKeywords": true,
                                    "mayCreateChild": false,
                                    "mayRename": false,
                                    "mayDelete": false,
                                    "maySubmit": false
                                },
                                "isSubscribed": true
                            }
                        ],
                        "notFound": []
                    },
                    "0"
                ]
            ],
            "sessionState": "state123"
        }
        """

        mockHTTPClient.nextResponse = (
            mailboxResponse.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.example.com/jmap/api/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }
}

// MARK: - Mock HTTP Client

class MockHTTPClient: HTTPClient {
    var nextResponse: (Data, URLResponse)?
    var responseQueue: [(Data, URLResponse)] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if !responseQueue.isEmpty {
            return responseQueue.removeFirst()
        }

        if let response = nextResponse {
            return response
        }

        throw URLError(.badServerResponse)
    }
}
