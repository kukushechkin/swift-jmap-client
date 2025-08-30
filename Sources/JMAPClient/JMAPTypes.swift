//
//  JMAPTypes.swift
//  JMAPClient
//

import Foundation

// MARK: - Core JMAP Types

/// JMAP Session information
public struct JMAPSession: Codable {
    public let capabilities: [String: JMAPCapability]
    public let accounts: [String: JMAPAccount]
    public let primaryAccounts: [String: String]
    public let username: String
    public let apiUrl: String
    public let downloadUrl: String
    public let uploadUrl: String
    public let eventSourceUrl: String
    public let state: String
}

/// JMAP Capability
public struct JMAPCapability: Codable {
    public let maxSizeUpload: Int?
    public let maxConcurrentUpload: Int?
    public let maxSizeRequest: Int?
    public let maxConcurrentRequests: Int?
    public let maxCallsInRequest: Int?
    public let maxObjectsInGet: Int?
    public let maxObjectsInSet: Int?
    public let collationAlgorithms: [String]?

    // Mail-specific capabilities
    public let maxSizeMailboxName: Int?
    public let maxMailboxDepth: Int?
    public let mayCreateTopLevelMailbox: Bool?
    public let maxSizeAttachmentsPerEmail: Int?
    public let maxMailboxesPerEmail: Int?
    public let emailQuerySortOptions: [String]?

    // Submission-specific capabilities
    public let maxDelayedSend: Int?
    public let submissionExtensions: [String: Bool]?
}

/// JMAP Account
public struct JMAPAccount: Codable {
    public let name: String
    public let isPersonal: Bool
    public let isReadOnly: Bool
    public let accountCapabilities: [String: JMAPCapability]
}

// MARK: - JMAP Request/Response Types

/// JMAP Request
public struct JMAPRequest: Codable {
    public let using: [String]
    public let methodCalls: [JMAPMethodCall]

    public init(using capabilities: [String], methodCalls: [JMAPMethodCall]) {
        self.using = capabilities
        self.methodCalls = methodCalls
    }
}

/// JMAP Method Call
public struct JMAPMethodCall: Codable {
    public let method: String
    public let arguments: [String: Any]
    public let clientId: String

    public init(method: String, arguments: [String: Any], clientId: String) {
        self.method = method
        self.arguments = arguments
        self.clientId = clientId
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.method = try container.decode(String.self)
        let args = try container.decode([String: AnyDecodable].self)
        self.arguments = args.mapValues { $0.value }
        self.clientId = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(method)

        // Convert arguments to properly encodable format
        let encodableArgs = try arguments.mapValues { value in
            try convertToEncodable(value)
        }

        try container.encode(encodableArgs)
        try container.encode(clientId)
    }

    private func convertToEncodable(_ value: Any) throws -> AnyEncodable {
        if let encodable = value as? Encodable {
            return AnyEncodable(encodable)
        } else if let dict = value as? [String: Any] {
            let encodableDict = try dict.mapValues { try convertToEncodable($0) }
            return AnyEncodable(encodableDict)
        } else if let array = value as? [Any] {
            let encodableArray = try array.map { try convertToEncodable($0) }
            return AnyEncodable(encodableArray)
        } else {
            // For basic types that should be encodable but aren't recognized
            if let string = value as? String {
                return AnyEncodable(string)
            } else if let int = value as? Int {
                return AnyEncodable(int)
            } else if let bool = value as? Bool {
                return AnyEncodable(bool)
            } else if let double = value as? Double {
                return AnyEncodable(double)
            } else {
                throw EncodingError.invalidValue(value, EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Cannot encode value of type \(type(of: value))"
                ))
            }
        }
    }
}

/// JMAP Response
public struct JMAPResponse: Codable {
    public let methodResponses: [JMAPMethodResponse]
    public let sessionState: String
    public let createdIds: [String: String]?

    enum CodingKeys: String, CodingKey {
        case methodResponses
        case sessionState
        case createdIds
    }
}

/// JMAP Method Response
public struct JMAPMethodResponse: Codable {
    public let method: String
    public let response: [String: Any]
    public let clientId: String

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.method = try container.decode(String.self)
        let resp = try container.decode([String: AnyDecodable].self)
        self.response = resp.mapValues { $0.value }
        self.clientId = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(method)
        let anyResponse = response.compactMapValues { value -> AnyEncodable? in
            if let encodable = value as? Encodable {
                return AnyEncodable(encodable)
            }
            return nil
        }
        try container.encode(anyResponse)
        try container.encode(clientId)
    }
}

// MARK: - Email Types

/// JMAP Email
public struct JMAPEmail: Codable, Identifiable {
    public let id: String
    public let blobId: String
    public let threadId: String
    public let mailboxIds: [String: Bool]
    public let keywords: [String: Bool]
    public let size: Int
    public let receivedAt: Date
    public let sentAt: Date?
    public let from: [JMAPEmailAddress]?
    public let to: [JMAPEmailAddress]?
    public let cc: [JMAPEmailAddress]?
    public let bcc: [JMAPEmailAddress]?
    public let replyTo: [JMAPEmailAddress]?
    public let subject: String?
    public let textBody: [JMAPEmailBodyPart]?
    public let htmlBody: [JMAPEmailBodyPart]?
    public let attachments: [JMAPEmailBodyPart]?
    public let hasAttachment: Bool
    public let preview: String?
    public let bodyValues: [String: JMAPEmailBodyValue]?

    public init(
        id: String = UUID().uuidString,
        blobId: String = "",
        threadId: String = UUID().uuidString,
        mailboxIds: [String: Bool],
        keywords: [String: Bool] = [:],
        size: Int = 0,
        receivedAt: Date = Date(),
        sentAt: Date? = nil,
        from: [JMAPEmailAddress]? = nil,
        to: [JMAPEmailAddress]? = nil,
        cc: [JMAPEmailAddress]? = nil,
        bcc: [JMAPEmailAddress]? = nil,
        replyTo: [JMAPEmailAddress]? = nil,
        subject: String? = nil,
        textBody: [JMAPEmailBodyPart]? = nil,
        htmlBody: [JMAPEmailBodyPart]? = nil,
        attachments: [JMAPEmailBodyPart]? = nil,
        hasAttachment: Bool = false,
        preview: String? = nil,
        bodyValues: [String: JMAPEmailBodyValue]? = nil
    ) {
        self.id = id
        self.blobId = blobId
        self.threadId = threadId
        self.mailboxIds = mailboxIds
        self.keywords = keywords
        self.size = size
        self.receivedAt = receivedAt
        self.sentAt = sentAt
        self.from = from
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.replyTo = replyTo
        self.subject = subject
        self.textBody = textBody
        self.htmlBody = htmlBody
        self.attachments = attachments
        self.hasAttachment = hasAttachment
        self.preview = preview
        self.bodyValues = bodyValues
    }
}

/// JMAP Email Address
public struct JMAPEmailAddress: Codable {
    public let name: String?
    public let email: String

    public init(name: String? = nil, email: String) {
        self.name = name
        self.email = email
    }
}

/// JMAP Email Body Part
public struct JMAPEmailBodyPart: Codable {
    public let partId: String?
    public let blobId: String?
    public let size: Int?
    public let headers: [JMAPEmailHeader]?
    public let name: String?
    public let type: String?
    public let charset: String?
    public let disposition: String?
    public let cid: String?
    public let language: [String]?
    public let location: String?
    public let subParts: [JMAPEmailBodyPart]?
}

/// JMAP Email Header
public struct JMAPEmailHeader: Codable {
    public let name: String
    public let value: String
}

/// JMAP Email Body Value
public struct JMAPEmailBodyValue: Codable {
    public let value: String
    public let isEncodingProblem: Bool?
    public let isTruncated: Bool?
}

// MARK: - Mailbox Types

/// JMAP Mailbox
public struct JMAPMailbox: Codable, Identifiable {
    public let id: String
    public let name: String
    public let parentId: String?
    public let role: JMAPMailboxRole?
    public let sortOrder: Int
    public let totalEmails: Int
    public let unreadEmails: Int
    public let totalThreads: Int
    public let unreadThreads: Int
    public let myRights: JMAPMailboxRights
    public let isSubscribed: Bool

    // Additional Fastmail-specific properties (optional)
    public let hidden: Int?
    public let autoPurge: Bool?
    public let purgeOlderThanDays: Int?
    public let suppressDuplicates: Bool?
    public let isCollapsed: Bool?
    public let autoLearn: Bool?
    public let learnAsSpam: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, parentId, role, sortOrder, totalEmails, unreadEmails
        case totalThreads, unreadThreads, myRights, isSubscribed
        case hidden, autoPurge, purgeOlderThanDays, suppressDuplicates
        case isCollapsed, autoLearn, learnAsSpam
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        parentId: String? = nil,
        role: JMAPMailboxRole? = nil,
        sortOrder: Int = 0,
        totalEmails: Int = 0,
        unreadEmails: Int = 0,
        totalThreads: Int = 0,
        unreadThreads: Int = 0,
        myRights: JMAPMailboxRights = JMAPMailboxRights(),
        isSubscribed: Bool = true,
        hidden: Int? = nil,
        autoPurge: Bool? = nil,
        purgeOlderThanDays: Int? = nil,
        suppressDuplicates: Bool? = nil,
        isCollapsed: Bool? = nil,
        autoLearn: Bool? = nil,
        learnAsSpam: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.role = role
        self.sortOrder = sortOrder
        self.totalEmails = totalEmails
        self.unreadEmails = unreadEmails
        self.totalThreads = totalThreads
        self.unreadThreads = unreadThreads
        self.myRights = myRights
        self.isSubscribed = isSubscribed
        self.hidden = hidden
        self.autoPurge = autoPurge
        self.purgeOlderThanDays = purgeOlderThanDays
        self.suppressDuplicates = suppressDuplicates
        self.isCollapsed = isCollapsed
        self.autoLearn = autoLearn
        self.learnAsSpam = learnAsSpam
    }
}

/// JMAP Mailbox Role
public enum JMAPMailboxRole: String, Codable, CaseIterable {
    case inbox = "inbox"
    case archive = "archive"
    case drafts = "drafts"
    case outbox = "outbox"
    case sent = "sent"
    case trash = "trash"
    case spam = "spam"
    case junk = "junk"  // Fastmail uses "junk" instead of "spam"
    case templates = "templates"
    case important = "important"
}

/// JMAP Mailbox Rights
public struct JMAPMailboxRights: Codable {
    public let mayReadItems: Bool
    public let mayAddItems: Bool
    public let mayRemoveItems: Bool
    public let maySetSeen: Bool
    public let maySetKeywords: Bool
    public let mayCreateChild: Bool
    public let mayRename: Bool
    public let mayDelete: Bool
    public let maySubmit: Bool
    public let mayAdmin: Bool?  // Fastmail-specific

    public init(
        mayReadItems: Bool = true,
        mayAddItems: Bool = true,
        mayRemoveItems: Bool = true,
        maySetSeen: Bool = true,
        maySetKeywords: Bool = true,
        mayCreateChild: Bool = true,
        mayRename: Bool = true,
        mayDelete: Bool = true,
        maySubmit: Bool = true,
        mayAdmin: Bool? = nil
    ) {
        self.mayReadItems = mayReadItems
        self.mayAddItems = mayAddItems
        self.mayRemoveItems = mayRemoveItems
        self.maySetSeen = maySetSeen
        self.maySetKeywords = maySetKeywords
        self.mayCreateChild = mayCreateChild
        self.mayRename = mayRename
        self.mayDelete = mayDelete
        self.maySubmit = maySubmit
        self.mayAdmin = mayAdmin
    }
}

// MARK: - Identity Types

/// JMAP Identity
public struct JMAPIdentity: Codable, Identifiable {
    public let id: String
    public let name: String
    public let email: String
    public let replyTo: [JMAPEmailAddress]?
    public let bcc: [JMAPEmailAddress]?
    public let textSignature: String?
    public let htmlSignature: String?
    public let mayDelete: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        replyTo: [JMAPEmailAddress]? = nil,
        bcc: [JMAPEmailAddress]? = nil,
        textSignature: String? = nil,
        htmlSignature: String? = nil,
        mayDelete: Bool = true
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.replyTo = replyTo
        self.bcc = bcc
        self.textSignature = textSignature
        self.htmlSignature = htmlSignature
        self.mayDelete = mayDelete
    }
}

// MARK: - Email Submission Types

/// JMAP Email Submission
public struct JMAPEmailSubmission: Codable, Identifiable {
    public let id: String
    public let identityId: String?
    public let emailId: String?
    public let threadId: String?
    public let envelope: JMAPEnvelope?
    public let sendAt: Date
    public let undoStatus: JMAPUndoStatus
    public let deliveryStatus: [String: JMAPDeliveryStatus]?
    public let dsnBlobIds: [String]?
    public let mdnBlobIds: [String]?

    public init(
        id: String = UUID().uuidString,
        identityId: String? = nil,
        emailId: String? = nil,
        threadId: String? = nil,
        envelope: JMAPEnvelope? = nil,
        sendAt: Date = Date(),
        undoStatus: JMAPUndoStatus = .pending,
        deliveryStatus: [String: JMAPDeliveryStatus]? = nil,
        dsnBlobIds: [String]? = nil,
        mdnBlobIds: [String]? = nil
    ) {
        self.id = id
        self.identityId = identityId
        self.emailId = emailId
        self.threadId = threadId
        self.envelope = envelope
        self.sendAt = sendAt
        self.undoStatus = undoStatus
        self.deliveryStatus = deliveryStatus
        self.dsnBlobIds = dsnBlobIds
        self.mdnBlobIds = mdnBlobIds
    }
}

/// JMAP Envelope
public struct JMAPEnvelope: Codable {
    public let mailFrom: JMAPEmailAddress
    public let rcptTo: [JMAPEmailAddress]
}

/// JMAP Undo Status
public enum JMAPUndoStatus: String, Codable {
    case pending = "pending"
    case final = "final"
    case canceled = "canceled"
}

/// JMAP Delivery Status
public struct JMAPDeliveryStatus: Codable {
    public let smtpReply: String
    public let delivered: JMAPDelivered
    public let displayed: JMAPDisplayed
}

/// JMAP Delivered Status
public enum JMAPDelivered: String, Codable {
    case queued = "queued"
    case yes = "yes"
    case no = "no"
    case unknown = "unknown"
}

/// JMAP Displayed Status
public enum JMAPDisplayed: String, Codable {
    case unknown = "unknown"
    case yes = "yes"
    case no = "no"
}

// MARK: - Query Types

/// JMAP Email Query
public struct JMAPEmailQuery: Codable {
    public let filter: JMAPEmailFilterCondition?
    public let sort: [JMAPEmailComparator]?
    public let position: Int?
    public let anchor: String?
    public let anchorOffset: Int?
    public let limit: Int?
    public let calculateTotal: Bool?

    public init(
        filter: JMAPEmailFilterCondition? = nil,
        sort: [JMAPEmailComparator]? = nil,
        position: Int? = nil,
        anchor: String? = nil,
        anchorOffset: Int? = nil,
        limit: Int? = nil,
        calculateTotal: Bool? = nil
    ) {
        self.filter = filter
        self.sort = sort
        self.position = position
        self.anchor = anchor
        self.anchorOffset = anchorOffset
        self.limit = limit
        self.calculateTotal = calculateTotal
    }
}

/// JMAP Email Filter Condition
public struct JMAPEmailFilterCondition: Codable {
    public let inMailbox: String?
    public let inMailboxOtherThan: [String]?
    public let before: Date?
    public let after: Date?
    public let minSize: Int?
    public let maxSize: Int?
    public let allInThreadHaveKeyword: String?
    public let someInThreadHaveKeyword: String?
    public let noneInThreadHaveKeyword: String?
    public let hasKeyword: String?
    public let notKeyword: String?
    public let hasAttachment: Bool?
    public let text: String?
    public let from: String?
    public let to: String?
    public let cc: String?
    public let bcc: String?
    public let subject: String?
    public let body: String?
    public let header: [String]?
}

/// JMAP Email Comparator
public struct JMAPEmailComparator: Codable {
    public let property: String
    public let isAscending: Bool?
    public let collation: String?

    public init(property: String, isAscending: Bool? = nil, collation: String? = nil) {
        self.property = property
        self.isAscending = isAscending
        self.collation = collation
    }
}

// MARK: - Helper Types for Any Codable

public struct AnyEncodable: Encodable {
    private let encodable: Encodable

    public init<T: Encodable>(_ encodable: T) {
        self.encodable = encodable
    }

    public func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}

public struct AnyDecodable: Decodable {
    public let value: Any

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode value")
            )
        }
    }
}

// MARK: - Constants

public struct JMAPCapabilities {
    public static let core = "urn:ietf:params:jmap:core"
    public static let mail = "urn:ietf:params:jmap:mail"
    public static let submission = "urn:ietf:params:jmap:submission"
}

public struct JMAPMethods {
    public static let emailGet = "Email/get"
    public static let emailSet = "Email/set"
    public static let emailQuery = "Email/query"
    public static let emailQueryChanges = "Email/queryChanges"
    public static let emailChanges = "Email/changes"

    public static let mailboxGet = "Mailbox/get"
    public static let mailboxSet = "Mailbox/set"
    public static let mailboxQuery = "Mailbox/query"
    public static let mailboxChanges = "Mailbox/changes"

    public static let identityGet = "Identity/get"
    public static let identitySet = "Identity/set"
    public static let identityChanges = "Identity/changes"

    public static let emailSubmissionGet = "EmailSubmission/get"
    public static let emailSubmissionSet = "EmailSubmission/set"
    public static let emailSubmissionQuery = "EmailSubmission/query"
    public static let emailSubmissionChanges = "EmailSubmission/changes"
}

public struct JMAPKeywords {
    public static let seen = "$seen"
    public static let flagged = "$flagged"
    public static let answered = "$answered"
    public static let draft = "$draft"
}
