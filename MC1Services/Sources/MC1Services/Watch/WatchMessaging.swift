import Foundation

/// Identifies a conversation in requests between the watch and the iPhone.
public struct WatchConversationRef: Codable, Hashable, Sendable {
  public let id: UUID
  public let kind: WatchSnapshot.ConversationSummary.Kind

  public init(id: UUID, kind: WatchSnapshot.ConversationSummary.Kind) {
    self.id = id
    self.kind = kind
  }

  /// Direct messages and channels go through the iPhone's send queue; rooms do not yet.
  public var canSend: Bool {
    kind != .room
  }
}

/// A request the watch app sends to the iPhone app as a live WatchConnectivity message.
public enum WatchRequest: WatchConnectivityPayload, Equatable, Sendable {
  /// Send the current snapshot back.
  case snapshot
  /// Send back the latest messages of a conversation.
  case recentMessages(WatchConversationRef)
  /// Queue `text` to a conversation. The iPhone answers with `WatchReply.sendResult` for `id`.
  case send(id: UUID, conversation: WatchConversationRef, text: String)

  public static let payloadKey = "watchRequest"

  /// Describes the request for logs, without message text.
  public var logDescription: String {
    switch self {
    case .snapshot: "snapshot"
    case let .recentMessages(conversation): "recent messages (\(conversation.kind.rawValue))"
    case let .send(_, conversation, _): "send (\(conversation.kind.rawValue))"
    }
  }
}

/// A reply the iPhone app sends to the watch app.
public enum WatchReply: WatchConnectivityPayload, Equatable, Sendable {
  /// The latest messages of a conversation, oldest first.
  case recentMessages(WatchConversationRef, [WatchMessage])
  /// What became of the `WatchRequest.send` with this `id`.
  case sendResult(id: UUID, outcome: WatchSendOutcome)

  public static let payloadKey = "watchReply"

  /// Describes the reply for logs, without message text.
  public var logDescription: String {
    switch self {
    case let .recentMessages(_, messages): "recent messages (\(messages.count))"
    case .sendResult(_, .queued): "send queued"
    case .sendResult(_, .failed): "send failed"
    }
  }
}

/// What became of a message sent from the watch. Like the Send Message shortcut, `queued`
/// means the message is in the radio's durable send queue, not yet acknowledged by the mesh.
public enum WatchSendOutcome: Codable, Equatable, Sendable {
  case queued
  case failed(reason: String)
}
