import Foundation
@testable import MC1Services
import Testing

@Suite("Watch messaging")
struct WatchMessagingTests {
  private let channel = WatchConversationRef(id: UUID(), kind: .channel)

  @Test
  func `requests round-trip and are property-list safe`() throws {
    let requests: [WatchRequest] = [
      .snapshot,
      .recentMessages(channel),
      .send(id: UUID(), conversation: channel, text: "On my way 👍")
    ]

    for request in requests {
      let payload = try request.payload()
      #expect(PropertyListSerialization.propertyList(payload, isValidFor: .binary))
      #expect(try WatchRequest(payload: payload) == request)
    }
  }

  @Test
  func `replies round-trip`() throws {
    let message = WatchMessage(
      id: UUID(),
      text: "Net check",
      date: Date(timeIntervalSince1970: 1_700_000_000),
      isOutgoing: false,
      senderName: "Ridge",
      status: nil,
      senderColor: WatchColor(red: 0.9, green: 0.5, blue: 0.2)
    )
    let replies: [WatchReply] = [
      .recentMessages(channel, [message]),
      .sendResult(id: UUID(), outcome: .queued),
      .sendResult(id: UUID(), outcome: .failed(reason: "Not connected"))
    ]

    for reply in replies {
      #expect(try WatchReply(payload: reply.payload()) == reply)
    }
  }

  @Test
  func `payload types do not decode each other`() throws {
    let request = try WatchRequest.snapshot.payload()

    #expect(try WatchReply(payload: request) == nil)
    #expect(try WatchSnapshot(payload: request) == nil)
  }

  @Test
  func `rooms cannot be sent to from the watch`() {
    #expect(WatchConversationRef(id: UUID(), kind: .direct).canSend)
    #expect(channel.canSend)
    #expect(!WatchConversationRef(id: UUID(), kind: .room).canSend)
  }

  @Test
  func `recent messages are the latest chat messages oldest first`() {
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    // Newest first, as PersistenceStore fetches them.
    let fetched = (0..<5).reversed().map { index in
      MessageDTO.testDirectMessage(text: "Message \(index)", createdAt: base.addingTimeInterval(Double(index)), direction: .incoming)
    }

    let recent = WatchMessage.recent(from: fetched, isDM: true, limit: 3)

    #expect(recent.map(\.text) == ["Message 2", "Message 3", "Message 4"])
  }

  @Test
  func `recent messages skip CLI traffic and sent reactions`() {
    let chat = MessageDTO.testDirectMessage(text: "Hello", direction: .incoming)
    let cli = MessageDTO.testDirectMessage(text: "status", direction: .outgoing, textType: .cliCommand)
    let sentReaction = MessageDTO.testDirectMessage(text: ReactionParser.buildDMReactionText(emoji: "👍", targetText: "Hello", targetTimestamp: 1), direction: .outgoing, status: .sent)

    let recent = WatchMessage.recent(from: [sentReaction, cli, chat], isDM: true)

    #expect(recent.map(\.text) == ["Hello"])
  }

  @Test
  func `outgoing messages carry their delivery status`() {
    let pending = WatchMessage(MessageDTO.testDirectMessage(direction: .outgoing, status: .retrying))
    let delivered = WatchMessage(MessageDTO.testDirectMessage(direction: .outgoing, status: .delivered))
    let incoming = WatchMessage(MessageDTO.testDirectMessage(direction: .incoming, status: .delivered))

    #expect(pending.status == .sending)
    #expect(delivered.status == .delivered)
    #expect(incoming.status == nil)
    #expect(incoming.isOutgoing == false)
  }
}
