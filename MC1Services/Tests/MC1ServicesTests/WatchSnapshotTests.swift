import Foundation
@testable import MC1Services
import Testing

@Suite("WatchSnapshot")
struct WatchSnapshotTests {
  private func makeSummary(index: Int, unread: Int = 0) -> WatchSnapshot.ConversationSummary {
    WatchSnapshot.ConversationSummary(
      id: UUID(),
      kind: .direct,
      name: "Contact \(index)",
      lastMessageDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
      unreadCount: unread,
      isMuted: false
    )
  }

  @Test("Round-trips through an application context")
  func roundTrip() throws {
    let snapshot = WatchSnapshot(
      connection: .connected,
      deviceName: "Heltec V3",
      totalUnread: 3,
      conversations: [makeSummary(index: 0, unread: 3), makeSummary(index: 1)]
    )

    let decoded = try WatchSnapshot(applicationContext: snapshot.applicationContext())

    #expect(decoded == snapshot)
  }

  @Test("Application context holds only property-list types")
  func contextIsPropertyListSafe() throws {
    let snapshot = WatchSnapshot(connection: .disconnected, deviceName: nil, totalUnread: 0, conversations: [])

    let context = try snapshot.applicationContext()

    #expect(PropertyListSerialization.propertyList(context, isValidFor: .binary))
  }

  @Test("A context without a snapshot decodes to nil")
  func missingSnapshotIsNil() throws {
    #expect(try WatchSnapshot(applicationContext: [:]) == nil)
  }

  @Test("Conversations are capped at maxConversations, keeping the first rows")
  func capsConversations() {
    let summaries = (0..<(WatchSnapshot.maxConversations + 5)).map { makeSummary(index: $0) }

    let snapshot = WatchSnapshot(connection: .connected, deviceName: nil, totalUnread: 0, conversations: summaries)

    #expect(snapshot.conversations.count == WatchSnapshot.maxConversations)
    #expect(snapshot.conversations.first == summaries.first)
  }
}
