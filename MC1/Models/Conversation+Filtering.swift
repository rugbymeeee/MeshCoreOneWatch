import Foundation
import MC1Services

extension Conversation {
  /// Chat-list rows for fetched data, unsorted. Hides repeaters, blocked contacts,
  /// unnamed channels without a secret, and any id in `hiddenIDs`.
  static func chatListRows(
    contacts: [ContactDTO],
    channels: [ChannelDTO],
    rooms: [RemoteNodeSessionDTO],
    hiding hiddenIDs: Set<UUID> = []
  ) -> [Conversation] {
    let contactConversations = contacts
      .filter { $0.type != .repeater && !$0.isBlocked && !hiddenIDs.contains($0.id) }
      .map { Conversation.direct($0) }
    let channelConversations = channels
      .filter { (!$0.name.isEmpty || $0.hasSecret) && !hiddenIDs.contains($0.id) }
      .map { Conversation.channel($0) }
    let roomConversations = rooms
      .filter { !hiddenIDs.contains($0.id) }
      .map { Conversation.room($0) }
    return contactConversations + channelConversations + roomConversations
  }
}

extension [Conversation] {
  /// Filters conversations by category and search text
  /// - Parameters:
  ///   - filter: Filter category
  ///   - searchText: Search string to match against display names
  /// - Returns: Filtered array of conversations
  func filtered(by filter: ChatFilter, searchText: String) -> [Conversation] {
    // When searching, ignore the selected filter and search all conversations
    if !searchText.isEmpty {
      return self.filter { conversation in
        conversation.displayName.localizedStandardContains(searchText)
      }
    }

    switch filter {
    case .all:
      return self
    case .unread:
      return self.filter { $0.isUnread && !$0.isMuted }
    case .directMessages:
      return self.filter {
        if case .direct = $0 { return true }
        return false
      }
    case .channels:
      return self.filter {
        if case .channel = $0 { return true }
        return false
      }
    case .rooms:
      return self.filter {
        if case .room = $0 { return true }
        return false
      }
    }
  }
}
