import Foundation
import MC1Services

extension AppState {
  /// Schedules a watch snapshot publish. Cheap to call often: sends are coalesced
  /// and skipped entirely when no watch has the app installed.
  func requestWatchSnapshot() {
    watchSyncService.requestPublish { [weak self] in
      await self?.makeWatchSnapshot()
    }
  }

  /// Republishes on every connection state change, so the watch follows connecting,
  /// ready, and lost no matter which lifecycle callback (if any) accompanies the change.
  func observeConnectionStateForWatch() {
    withObservationTracking {
      _ = connectionState
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.requestWatchSnapshot()
        self?.observeConnectionStateForWatch()
      }
    }
  }

  /// Builds the snapshot from the current radio's stored conversations, using the
  /// same row rules and ordering as the iPhone chat list (pins first, then most recent).
  func makeWatchSnapshot() async -> WatchSnapshot {
    let connection: WatchSnapshot.Connection = switch connectionState {
    case .connected, .syncing, .ready: .connected
    case .connecting: .connecting
    case .disconnected: .disconnected
    }
    let deviceName = connection == .connected ? connectedDevice?.nodeName : nil

    guard let store = offlineDataStore, let radioID = currentRadioID else {
      return WatchSnapshot(connection: connection, deviceName: deviceName, totalUnread: 0, conversations: [])
    }

    let contacts = await (try? store.fetchConversations(radioID: radioID)) ?? []
    let channels = await (try? store.fetchChannels(radioID: radioID)) ?? []
    let rooms = await (try? store.fetchRemoteNodeSessions(radioID: radioID))?.filter(\.isRoom) ?? []
    let totalUnread = await conversationUnreadOperations.read(store, radioID)

    let rows = Conversation.chatListRows(contacts: contacts, channels: channels, rooms: rooms)
    let byRecency: (Conversation, Conversation) -> Bool = {
      ($0.lastMessageDate ?? .distantPast) > ($1.lastMessageDate ?? .distantPast)
    }
    let ordered = rows.filter(\.isPinned).sorted(by: byRecency) + rows.filter { !$0.isPinned }.sorted(by: byRecency)

    return WatchSnapshot(
      connection: connection,
      deviceName: deviceName,
      totalUnread: totalUnread,
      conversations: ordered.map(\.watchSummary)
    )
  }
}

private extension Conversation {
  var watchSummary: WatchSnapshot.ConversationSummary {
    let kind: WatchSnapshot.ConversationSummary.Kind = switch self {
    case .direct: .direct
    case .channel: .channel
    case .room: .room
    }
    return WatchSnapshot.ConversationSummary(
      id: id,
      kind: kind,
      name: displayName,
      lastMessageDate: lastMessageDate,
      unreadCount: unreadCount,
      isMuted: isMuted
    )
  }
}
