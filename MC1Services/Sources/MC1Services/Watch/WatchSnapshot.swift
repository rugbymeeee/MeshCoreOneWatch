import Foundation

/// Latest-wins summary the iPhone app publishes to its Apple Watch app.
///
/// Carried as JSON inside a WatchConnectivity application context, so it stays a small,
/// property-list-safe payload. Holds no timestamps of its own, so two snapshots built from
/// unchanged data compare equal and the publisher can skip a redundant send.
public struct WatchSnapshot: Codable, Equatable, Sendable {
  /// Radio link state as the watch shows it.
  public enum Connection: String, Codable, Sendable {
    case connected
    case connecting
    case disconnected
  }

  /// One chat-list row.
  public struct ConversationSummary: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
      case direct
      case channel
      case room
    }

    public let id: UUID
    public let kind: Kind
    public let name: String
    public let lastMessageDate: Date?
    public let unreadCount: Int
    public let isMuted: Bool

    public init(id: UUID, kind: Kind, name: String, lastMessageDate: Date?, unreadCount: Int, isMuted: Bool) {
      self.id = id
      self.kind = kind
      self.name = name
      self.lastMessageDate = lastMessageDate
      self.unreadCount = unreadCount
      self.isMuted = isMuted
    }
  }

  /// Rows sent to the watch. Keeps the payload well under the application context limit.
  public static let maxConversations = 20

  /// Application context key holding the encoded snapshot.
  static let contextKey = "watchSnapshot"

  /// Message key and value the watch sends to ask the iPhone for a fresh snapshot.
  static let requestKey = "request"
  static let refreshRequestValue = "watchSnapshot"

  /// Message the watch sends to ask the iPhone for a fresh snapshot.
  public static var refreshRequest: [String: Any] {
    [requestKey: refreshRequestValue]
  }

  /// Whether a received WatchConnectivity message is a refresh request.
  public static func isRefreshRequest(_ message: [String: Any]) -> Bool {
    message[requestKey] as? String == refreshRequestValue
  }

  public var connection: Connection
  public var deviceName: String?
  public var totalUnread: Int
  public var conversations: [ConversationSummary]

  /// Truncates `conversations` to `maxConversations`; callers pass them already sorted.
  public init(connection: Connection, deviceName: String?, totalUnread: Int, conversations: [ConversationSummary]) {
    self.connection = connection
    self.deviceName = deviceName
    self.totalUnread = totalUnread
    self.conversations = Array(conversations.prefix(Self.maxConversations))
  }

  /// Encodes into a WatchConnectivity application context.
  public func applicationContext() throws -> [String: Any] {
    try [Self.contextKey: JSONEncoder().encode(self)]
  }

  /// Decodes from a received application context. Returns nil when the context holds no snapshot.
  public init?(applicationContext: [String: Any]) throws {
    guard let data = applicationContext[Self.contextKey] as? Data else { return nil }
    self = try JSONDecoder().decode(Self.self, from: data)
  }
}
