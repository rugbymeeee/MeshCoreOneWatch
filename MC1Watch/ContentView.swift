import MC1WatchShared
import SwiftUI

/// Home screen: radio status and the iPhone's most recent conversations.
struct ContentView: View {
  let receiver: WatchSnapshotReceiver

  private var snapshot: WatchSnapshot? {
    receiver.snapshot
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          ConnectionRow(connection: snapshot?.connection ?? .disconnected, deviceName: snapshot?.deviceName)
        } footer: {
          if snapshot == nil {
            Text(L10n.Watch.Home.Footer.noData)
          } else if !receiver.isPhoneReachable {
            Text(L10n.Watch.Home.Footer.unreachable)
          }
        }

        if let snapshot {
          Section(L10n.Watch.Home.conversations) {
            if snapshot.conversations.isEmpty {
              Text(L10n.Watch.Home.empty)
                .foregroundStyle(.secondary)
            } else {
              ForEach(snapshot.conversations) { conversation in
                ConversationRow(conversation: conversation)
              }
            }
          }
        }

        if receiver.isPhoneReachable {
          Section {
            Button(L10n.Watch.Home.refresh, systemImage: "arrow.clockwise", action: receiver.requestRefresh)
          }
        }
      }
      .navigationTitle(L10n.Watch.Home.title)
    }
  }
}

/// Radio status, in the iPhone's status colors.
private struct ConnectionRow: View {
  let connection: WatchSnapshot.Connection
  let deviceName: String?

  var body: some View {
    switch connection {
    case .connected:
      Label(deviceName ?? L10n.Watch.Connection.connected, systemImage: "antenna.radiowaves.left.and.right")
        .foregroundStyle(.green)
    case .connecting:
      Label(L10n.Watch.Connection.connecting, systemImage: "antenna.radiowaves.left.and.right")
        .foregroundStyle(.blue)
    case .disconnected:
      Label(L10n.Watch.Connection.notConnected, systemImage: "antenna.radiowaves.left.and.right.slash")
        .foregroundStyle(.secondary)
    }
  }
}

/// A Chats list row: avatar, name, time, notification level, and unread badges as on the iPhone.
private struct ConversationRow: View {
  let conversation: WatchSnapshot.ConversationSummary

  @ScaledMetric(relativeTo: .headline) private var avatarSize: CGFloat = 30

  var body: some View {
    HStack(spacing: 8) {
      KindAvatar(kind: conversation.kind, size: avatarSize)

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

/// A conversation's kind as a symbol on a gray circle: a person, a channel, or a room.
private struct KindAvatar: View {
  let kind: WatchSnapshot.ConversationSummary.Kind
  let size: CGFloat

  private var symbolName: String {
    switch kind {
    case .direct: "person.fill"
    case .channel: "number"
    case .room: "door.left.hand.closed"
    }
  }

  private var label: String {
    switch kind {
    case .direct: L10n.Watch.Accessibility.directMessage
    case .channel: L10n.Watch.Accessibility.channel
    case .room: L10n.Watch.Accessibility.room
    }
  }

  var body: some View {
    Image(systemName: symbolName)
      .font(.system(size: size * 0.4, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(Color.gray, in: .circle)
      .accessibilityLabel(label)
  }
}

private struct NotificationLevelIcon: View {
  let level: WatchNotificationLevel

  var body: some View {
    switch level {
    case .muted:
      Image(systemName: level.iconName)
        .accessibilityLabel(L10n.Watch.Accessibility.muted)
    case .mentionsOnly:
      Image(systemName: level.iconName)
        .accessibilityLabel(L10n.Watch.Accessibility.mentionsOnly)
    case .all:
      EmptyView()
    }
  }
}

/// The iPhone's unread badges: "@" for unread mentions, then the unread count. Both turn gray
/// when the conversation does not notify on every message.
private struct UnreadBadges: View {
  let conversation: WatchSnapshot.ConversationSummary

  @ScaledMetric(relativeTo: .caption2) private var mentionBadgeSize: CGFloat = 18

  var body: some View {
    HStack(spacing: 3) {
      if conversation.unreadMentionCount > 0 {
        Text(verbatim: "@")
          .font(.caption2.bold())
          .foregroundStyle(.white)
          .frame(width: mentionBadgeSize, height: mentionBadgeSize)
          .background(conversation.isMuted ? Color.gray : Color.blue, in: .circle)
          .accessibilityLabel(L10n.Watch.Accessibility.unreadMention)
      }
      if conversation.unreadCount > 0 {
        Text(conversation.unreadCount, format: .number)
          .font(.caption2.bold())
          .foregroundStyle(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(conversation.notificationLevel == .all ? Color.blue : Color.gray, in: .capsule)
          .accessibilityLabel(L10n.Watch.Accessibility.unreadCount(conversation.unreadCount))
      }
    }
  }
}
