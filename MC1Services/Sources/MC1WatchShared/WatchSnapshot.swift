import Foundation

/// Latest-wins summary the iPhone app publishes to its Apple Watch app.
///
/// Carried in a WatchConnectivity application context, so it stays a small payload. Holds no
/// timestamps of its own, so two snapshots built from unchanged data compare equal and the
/// publisher can skip a redundant send.
public struct WatchSnapshot: WatchConnectivityPayload, Equatable, Sendable {
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
    public let unreadMentionCount: Int
    public let notificationLevel: WatchNotificationLevel

    public init(
      id: UUID,
      kind: Kind,
      name: String,
      lastMessageDate: Date?,
      unreadCount: Int,
      unreadMentionCount: Int = 0,
      notificationLevel: WatchNotificationLevel = .all
    ) {
      self.id = id
      self.kind = kind
      self.name = name
      self.lastMessageDate = lastMessageDate
      self.unreadCount = unreadCount
      self.unreadMentionCount = unreadMentionCount
      self.notificationLevel = notificationLevel
    }

    public var isMuted: Bool {
      notificationLevel == .muted
    }
  }

  /// Rows sent to the watch. Keeps the payload well under the application context limit.
  public static let maxConversations = 20

  public static let payloadKey = "watchSnapshot"

  public var connection: Connection
  public var deviceName: String?
  public var totalUnread: Int
  public var conversations: [ConversationSummary]

  /// Truncates `conversations` to `maxConversations`; callers pass them already sorted.
  public init(
    connection: Connection,
    deviceName: String?,
    totalUnread: Int,
    conversations: [ConversationSummary]
  ) {
    self.connection = connection
    self.deviceName = deviceName
    self.totalUnread = totalUnread
    self.conversations = Array(conversations.prefix(Self.maxConversations))
  }
}
