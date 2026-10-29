import MC1Services
import SwiftUI

/// Home screen: radio status and the iPhone's most recent conversations.
struct ContentView: View {
  let snapshot: WatchSnapshot?

  var body: some View {
    NavigationStack {
      List {
        Section {
          ConnectionRow(connection: snapshot?.connection ?? .disconnected, deviceName: snapshot?.deviceName)
        } footer: {
          if snapshot == nil {
            Text("Open MeshCore One on your iPhone to connect a radio.")
          }
        }

        if let snapshot {
          Section("Conversations") {
            if snapshot.conversations.isEmpty {
              Text("No Conversations")
                .foregroundStyle(.secondary)
            } else {
              ForEach(snapshot.conversations) { conversation in
                ConversationRow(conversation: conversation)
              }
            }
          }
        }
      }
      .navigationTitle("MeshCore One")
    }
  }
}

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
        .foregroundStyle(.orange)
    case .disconnected:
      Label("Not Connected", systemImage: "antenna.radiowaves.left.and.right.slash")
        .foregroundStyle(.secondary)
    }
  }
}

private struct ConversationRow: View {
  let conversation: WatchSnapshot.ConversationSummary

  private var iconName: String {
    switch conversation.kind {
    case .direct: "person.fill"
    case .channel: "number"
    case .room: "bubble.left.and.bubble.right.fill"
    }
  }

  var body: some View {
    HStack {
      Image(systemName: iconName)
        .foregroundStyle(.secondary)
        .frame(width: 20)

      VStack(alignment: .leading) {
        Text(conversation.name)
          .lineLimit(1)
        if let date = conversation.lastMessageDate {
          Text(date, format: .relative(presentation: .named))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 0)

      if conversation.isMuted {
        Image(systemName: "bell.slash.fill")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      if conversation.unreadCount > 0 {
        Text(conversation.unreadCount, format: .number)
          .font(.footnote.bold())
          .padding(.horizontal, 6)
          .background(Capsule().fill(conversation.isMuted ? Color.gray : Color.blue))
      }
    }
  }
}
