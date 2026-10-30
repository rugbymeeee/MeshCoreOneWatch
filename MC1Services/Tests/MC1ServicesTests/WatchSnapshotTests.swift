import Foundation
@testable import MC1Services
import MC1WatchShared
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

  @Test
  func `round-trips through an application context`() throws {
    let channel = WatchSnapshot.ConversationSummary(
      id: UUID(),
      kind: .channel,
      name: "#hiking",
      lastMessageDate: nil,
      unreadCount: 2,
      unreadMentionCount: 1,
      notificationLevel: .mentionsOnly
    )
    let room = WatchSnapshot.ConversationSummary(
      id: UUID(),
      kind: .room,
      name: "Basecamp",
      lastMessageDate: Date(timeIntervalSince1970: 1_700_000_500),
      unreadCount: 0,
      notificationLevel: .muted
    )
    let snapshot = WatchSnapshot(
      connection: .connected,
      deviceName: "Heltec V3",
      totalUnread: 3,
      conversations: [makeSummary(index: 0, unread: 1), channel, room]
    )

    let decoded = try WatchSnapshot(payload: snapshot.payload())

    #expect(decoded == snapshot)
  }

  @Test
  func `only the muted notification level counts as muted`() {
    let levels: [WatchNotificationLevel: Bool] = [.muted: true, .mentionsOnly: false, .all: false]

    for (level, isMuted) in levels {
      let summary = WatchSnapshot.ConversationSummary(id: UUID(), kind: .direct, name: "A", lastMessageDate: nil, unreadCount: 0, notificationLevel: level)
      #expect(summary.isMuted == isMuted)
    }
  }

  @Test
  func `notification levels mirror the iPhone setting and its icon`() {
    for level in NotificationLevel.allCases {
      let mirrored = WatchNotificationLevel(level)
      #expect(mirrored.iconName == level.iconName)
      #expect((mirrored == .muted) == (level == .muted))
    }
    #expect(WatchNotificationLevel(.mentionsOnly) == .mentionsOnly)
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

  /// Every row at its largest: a long name with emoji, and every count and date set.
  @Test
  func `the largest snapshot stays a small payload`() throws {
    let longName = String(repeating: "W", count: 60) + " 🛰️📡"
    let summaries = (0..<WatchSnapshot.maxConversations).map { index in
      WatchSnapshot.ConversationSummary(
        id: UUID(),
        kind: .channel,
        name: longName,
        lastMessageDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
        unreadCount: 9999,
        unreadMentionCount: 999,
        notificationLevel: .mentionsOnly
      )
    }
    let snapshot = WatchSnapshot(connection: .connecting, deviceName: longName, totalUnread: 99999, conversations: summaries)

    let payload = try snapshot.payload()
    let data = try #require(payload[WatchSnapshot.payloadKey] as? Data)

    #expect(data.count < 16 * 1024)
  }

  @Test
  func `a refresh request round-trips and is not taken for a snapshot`() throws {
    let payload = try WatchRequest.snapshot.payload()

    #expect(PropertyListSerialization.propertyList(payload, isValidFor: .binary))
    #expect(try WatchRequest(payload: payload) == .snapshot)
    #expect(try WatchSnapshot(payload: payload) == nil)
  }
}
