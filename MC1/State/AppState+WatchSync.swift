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

  /// Answers a watch request other than a snapshot refresh.
  func answerWatchRequest(_ request: WatchRequest) async -> WatchReply? {
    switch request {
    case .snapshot:
      requestWatchSnapshot()
      return nil
    case let .recentMessages(conversation):
      return await .recentMessages(conversation, watchMessages(for: conversation))
    case let .send(id, conversation, text):
      return await .sendResult(id: id, outcome: sendFromWatch(text, to: conversation))
    }
  }

  /// The latest messages of a conversation, oldest first.
  func watchMessages(for conversation: WatchConversationRef) async -> [WatchMessage] {
    guard let store = offlineDataStore, let radioID = currentRadioID else { return [] }
    let fetchLimit = WatchMessage.maxMessages * 2
    switch conversation.kind {
    case .direct:
      let messages = await (try? store.fetchMessages(contactID: conversation.id, limit: fetchLimit)) ?? []
      return WatchMessage.recent(from: messages, isDM: true)
    case .channel:
      guard let channel = await watchChannel(id: conversation.id, radioID: radioID, in: store) else { return [] }
      let messages = await (try? store.fetchMessages(radioID: radioID, channelIndex: channel.index, limit: fetchLimit)) ?? []
      return WatchMessage.recent(from: messages, isDM: false)
    case .room:
      return []
    }
  }

  /// Queues text typed on the watch through the Send Message shortcut's durable path, so it
  /// appears in the iPhone chat with the usual status and retries.
  func sendFromWatch(_ text: String, to conversation: WatchConversationRef) async -> WatchSendOutcome {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return .failed(reason: IntentError.sendFailed.localizedDescription) }

    // The watch cannot bring the iPhone app forward, so every not-ready rung fails here.
    switch SendMessageIntent.route(for: connectionManager.connectionState) {
    case .headlessQueue, .queueAfterSync:
      break
    case .foregroundEscalate, .notConnected:
      return .failed(reason: IntentError.notConnected.localizedDescription)
    }
    guard let recipient = await watchRecipient(for: conversation) else {
      return .failed(reason: IntentError.invalidRecipient.localizedDescription)
    }

    do {
      let nodeNameByteCount = connectedDevice?.nodeName.utf8.count ?? 0
      try SendMessageIntent.validate(message: text, for: recipient, nodeNameByteCount: nodeNameByteCount)
      switch try await SendMessageIntent.performSend(message: text, recipient: recipient, in: self) {
      case .queued:
        return .queued
      case .mustForeground:
        return .failed(reason: IntentError.notConnected.localizedDescription)
      }
    } catch {
      return .failed(reason: SendMessageIntent.mapToIntentError(error).localizedDescription)
    }
  }

  private func watchRecipient(for conversation: WatchConversationRef) async -> MessageRecipient? {
    guard let store = offlineDataStore, let radioID = currentRadioID else { return nil }
    switch conversation.kind {
    case .direct:
      guard let contact = try? await store.fetchContact(id: conversation.id),
            contact.radioID == radioID else { return nil }
      return .contact(contact)
    case .channel:
      return await watchChannel(id: conversation.id, radioID: radioID, in: store).map { .channel($0) }
    case .room:
      return nil
    }
  }

  private func watchChannel(id: UUID, radioID: UUID, in store: PersistenceStore) async -> ChannelDTO? {
    let channels = await (try? store.fetchChannels(radioID: radioID)) ?? []
    return channels.first { $0.id == id }
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
