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
      unreadCount: unread
    )
  }

  private let appearance = WatchAppearance(
    tint: nil,
    canvas: WatchColor(red: 0, green: 0, blue: 0),
    card: nil,
    outgoingBubble: WatchColor(red: 0.14, green: 0.39, blue: 0.92),
    outgoingText: WatchColor(red: 1, green: 1, blue: 1),
    incomingBubble: WatchColor(red: 0.17, green: 0.17, blue: 0.18)
  )

  @Test
  func `round-trips through an application context`() throws {
    let themed = WatchSnapshot.ConversationSummary(
      id: UUID(),
      kind: .channel,
      name: "#hiking",
      lastMessageDate: nil,
      unreadCount: 2,
      unreadMentionCount: 1,
      notificationLevel: .mentionsOnly,
      avatar: WatchAvatar(glyph: .symbol("number"), fill: WatchColor(red: 0.2, green: 0.4, blue: 0.53), glyphColor: WatchColor(red: 1, green: 1, blue: 1))
    )
    let snapshot = WatchSnapshot(
      connection: .connected,
      deviceName: "Heltec V3",
      totalUnread: 3,
      conversations: [makeSummary(index: 0, unread: 3), themed],
      appearance: appearance
    )

    let decoded = try WatchSnapshot(payload: snapshot.payload())

    #expect(decoded == snapshot)
  }

  @Test
  func `only the muted notification level counts as muted`() {
    let levels: [NotificationLevel: Bool] = [.muted: true, .mentionsOnly: false, .all: false]

    for (level, isMuted) in levels {
      let summary = WatchSnapshot.ConversationSummary(id: UUID(), kind: .direct, name: "A", lastMessageDate: nil, unreadCount: 0, notificationLevel: level)
      #expect(summary.isMuted == isMuted)
    }
  }

  @Test
  func `application context holds only property-list types`() throws {
    let snapshot = WatchSnapshot(connection: .disconnected, deviceName: nil, totalUnread: 0, conversations: [])

    let context = try snapshot.payload()

    #expect(PropertyListSerialization.propertyList(context, isValidFor: .binary))
  }

  @Test
  func `a context without a snapshot decodes to nil`() throws {
    #expect(try WatchSnapshot(payload: [:]) == nil)
  }

  @Test
  func `conversations are capped at maxConversations keeping the first rows`() {
    let summaries = (0..<(WatchSnapshot.maxConversations + 5)).map { makeSummary(index: $0) }

    let snapshot = WatchSnapshot(connection: .connected, deviceName: nil, totalUnread: 0, conversations: summaries)

    #expect(snapshot.conversations.count == WatchSnapshot.maxConversations)
    #expect(snapshot.conversations.first == summaries.first)
  }
}
