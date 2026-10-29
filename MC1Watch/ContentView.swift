import MC1Services
import SwiftUI

/// Home screen: radio status and the iPhone's most recent conversations.
struct ContentView: View {
  let receiver: WatchSnapshotReceiver

  @State private var path: [UUID] = []

  private var snapshot: WatchSnapshot? {
    receiver.snapshot
  }

  private var appearance: WatchAppearance? {
    snapshot?.appearance
  }

  var body: some View {
    NavigationStack(path: $path) {
      List {
        Section {
          ConnectionRow(connection: snapshot?.connection ?? .disconnected, deviceName: snapshot?.deviceName)
            .themedRow(appearance)
        } footer: {
          if snapshot == nil {
            Text("Open MeshCore One on your iPhone to connect a radio.")
          } else if !receiver.isPhoneReachable {
            Text("iPhone not reachable. Showing the last update.")
          }
        }

        if let snapshot {
          Section("Conversations") {
            if snapshot.conversations.isEmpty {
              Text("No Conversations")
                .foregroundStyle(.secondary)
                .themedRow(appearance)
            } else {
              ForEach(snapshot.conversations) { conversation in
                NavigationLink(value: conversation.id) {
                  ConversationRow(conversation: conversation)
                }
                .themedRow(appearance)
              }
            }
          }
        }

        if receiver.isPhoneReachable {
          Section {
            Button("Refresh", systemImage: "arrow.clockwise", action: receiver.requestRefresh)
              .themedRow(appearance)
          }
        }
      }
      .navigationTitle("MeshCore One")
      .navigationDestination(for: UUID.self) { id in
        if let conversation = snapshot?.conversations.first(where: { $0.id == id }) {
          ConversationView(conversation: conversation, receiver: receiver)
        }
      }
      .themedScreen(appearance)
    }
    .onChange(of: snapshot) { _, newSnapshot in
      openFirstConversationForCI(in: newSnapshot)
    }
  }

  /// CI hook (watch-simulator.yml): opens the first conversation that accepts messages.
  private func openFirstConversationForCI(in snapshot: WatchSnapshot?) {
    #if DEBUG
      guard UserDefaults.standard.bool(forKey: "openFirstConversation"), path.isEmpty,
            let conversation = snapshot?.conversations.first(where: { $0.ref.canSend }) else { return }
      path.append(conversation.id)
    #endif
  }
}

/// Radio status, in the iPhone's status colors.
private struct ConnectionRow: View {
  let connection: WatchSnapshot.Connection
  let deviceName: String?

  var body: some View {
    switch connection {
    case .connected:
      Label(deviceName ?? String(localized: "Connected"), systemImage: "antenna.radiowaves.left.and.right")
        .foregroundStyle(.green)
    case .connecting:
      Label("Connecting…", systemImage: "antenna.radiowaves.left.and.right")
        .foregroundStyle(.blue)
    case .disconnected:
      Label("Not Connected", systemImage: "antenna.radiowaves.left.and.right.slash")
        .foregroundStyle(.secondary)
    }
  }
}

/// A Chats list row: avatar, name, time, notification level, and unread badges as on the iPhone.
private struct ConversationRow: View {
  let conversation: WatchSnapshot.ConversationSummary

  private var kindLabel: LocalizedStringKey {
    switch conversation.kind {
    case .direct: "Direct Message"
    case .channel: "Channel"
    case .room: "Room"
    }
  }

  var body: some View {
    HStack(spacing: 8) {
      AvatarView(avatar: conversation.avatar, size: 30)
        .accessibilityLabel(Text(kindLabel))

      VStack(alignment: .leading, spacing: 1) {
        Text(conversation.name)
          .font(.headline)
          .lineLimit(1)
        HStack(spacing: 4) {
          if let date = conversation.lastMessageDate {
            Text(date, format: .relative(presentation: .named))
          }
          NotificationLevelIcon(level: conversation.notificationLevel)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      UnreadBadges(conversation: conversation)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct NotificationLevelIcon: View {
  let level: NotificationLevel

  var body: some View {
    switch level {
    case .muted:
      Image(systemName: level.iconName)
        .accessibilityLabel(Text("Muted"))
    case .mentionsOnly:
      Image(systemName: level.iconName)
        .accessibilityLabel(Text("Mentions Only"))
    case .all:
      EmptyView()
    }
  }
}

/// The iPhone's unread badges: "@" for unread mentions, then the unread count. Both turn gray
/// when the conversation does not notify on every message.
private struct UnreadBadges: View {
  let conversation: WatchSnapshot.ConversationSummary

  var body: some View {
    HStack(spacing: 3) {
      if conversation.unreadMentionCount > 0 {
        Text("@")
          .font(.caption2.bold())
          .foregroundStyle(.white)
          .frame(width: 18, height: 18)
          .background(conversation.isMuted ? Color.gray : Color.blue, in: .circle)
          .accessibilityLabel(Text("Unread mention"))
      }
      if conversation.unreadCount > 0 {
        Text(conversation.unreadCount, format: .number)
          .font(.caption2.bold())
          .foregroundStyle(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(conversation.notificationLevel == .all ? Color.blue : Color.gray, in: .capsule)
          .accessibilityLabel(Text("\(conversation.unreadCount) unread"))
      }
    }
  }
}
