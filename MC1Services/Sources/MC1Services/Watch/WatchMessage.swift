import Foundation

/// One message of a conversation as the watch shows it.
public struct WatchMessage: Codable, Equatable, Sendable, Identifiable {
  /// Delivery state of an outgoing message.
  public enum Status: String, Codable, Sendable {
    case sending
    case sent
    case delivered
    case failed
  }

  /// Messages sent per conversation. Keeps a reply well under the message size limit.
  public static let maxMessages = 15

  public let id: UUID
  public let text: String
  public let date: Date
  public let isOutgoing: Bool
  /// Who wrote an incoming channel message; nil for direct messages and outgoing ones.
  public let senderName: String?
  /// Delivery state of an outgoing message; nil for incoming ones.
  public let status: Status?
  /// The sender's identity color in the iPhone theme, set by the iPhone when it has one.
  public var senderColor: WatchColor?

  public init(
    id: UUID,
    text: String,
    date: Date,
    isOutgoing: Bool,
    senderName: String?,
    status: Status?,
    senderColor: WatchColor? = nil
  ) {
    self.id = id
    self.text = text
    self.date = date
    self.isOutgoing = isOutgoing
    self.senderName = senderName
    self.status = status
    self.senderColor = senderColor
  }
}

public extension WatchMessage {
  init(_ message: MessageDTO) {
    let isOutgoing = message.direction == .outgoing
    self.init(
      id: message.id,
      text: message.text,
      date: message.sortDate,
      isOutgoing: isOutgoing,
      senderName: isOutgoing ? nil : message.senderNodeName,
      status: isOutgoing ? Status(message.status) : nil
    )
  }

  /// The latest chat messages of a conversation, oldest first, from `messages` fetched newest
  /// first. Skips CLI traffic and the outgoing reactions the chat timeline also hides.
  static func recent(from messages: [MessageDTO], isDM: Bool, limit: Int = WatchMessage.maxMessages) -> [WatchMessage] {
    let visible = messages.filter { message in
      (message.textType == .plain || message.textType == .signedPlain)
        && !message.isHiddenOutgoingReaction(isDM: isDM)
    }
    return visible.prefix(limit).reversed().map { WatchMessage($0) }
  }
}

extension WatchMessage.Status {
  init(_ status: MessageStatus) {
    switch status {
    case .pending, .sending, .retrying: self = .sending
    case .sent: self = .sent
    case .delivered: self = .delivered
    case .failed: self = .failed
    }
  }
}
