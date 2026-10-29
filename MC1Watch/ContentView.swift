import MC1Services
import SwiftUI

/// Home screen: radio status and the iPhone's most recent conversations.
struct ContentView: View {
  let receiver: WatchSnapshotReceiver

  @State private var path: [UUID] = []

  private var snapshot: WatchSnapshot? {
    receiver.snapshot
  }

  var body: some View {
    NavigationStack(path: $path) {
      List {
        Section {
          ConnectionRow(connection: snapshot?.connection ?? .disconnected, deviceName: snapshot?.deviceName)
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
            } else {
              ForEach(snapshot.conversations) { conversation in
                NavigationLink(value: conversation.id) {
                  ConversationRow(conversation: conversation)
                }
              }
            }
          }
        }

        if receiver.isPhoneReachable {
          Section {
            Button("Refresh", systemImage: "arrow.clockwise", action: receiver.requestRefresh)
          }
        }
      }
      .navigationTitle("MeshCore One")
      .navigationDestination(for: UUID.self) { id in
        if let conversation = snapshot?.conversations.first(where: { $0.id == id }) {
          ConversationView(conversation: conversation, receiver: receiver)
        }
      }
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

  private var kind: (icon: String, label: LocalizedStringKey) {
    switch conversation.kind {
    case .direct: ("person.fill", "Direct Message")
    case .channel: ("number", "Channel")
    case .room: ("bubble.left.and.bubble.right.fill", "Room")
    }
  }

  var body: some View {
    HStack {
      Image(systemName: kind.icon)
        .foregroundStyle(.secondary)
        .frame(width: 20)
        .accessibilityLabel(Text(kind.label))

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
          .accessibilityLabel(Text("Muted"))
      }
      if conversation.unreadCount > 0 {
        Text(conversation.unreadCount, format: .number)
          .font(.footnote.bold())
          .padding(.horizontal, 6)
          .background(Capsule().fill(conversation.isMuted ? Color.gray : Color.blue))
          .accessibilityLabel(Text("\(conversation.unreadCount) unread"))
      }
    }
    .accessibilityElement(children: .combine)
  }
}
