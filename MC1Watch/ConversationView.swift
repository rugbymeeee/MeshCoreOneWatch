import MC1Services
import SwiftUI

/// A conversation's latest messages, answered by dictation, Scribble, the keyboard, or a quick reply.
struct ConversationView: View {
  let conversation: WatchSnapshot.ConversationSummary
  let receiver: WatchSnapshotReceiver

  @State private var draft = ""
  @State private var sendID: UUID?

  private static let quickReplies: [LocalizedStringResource] = ["OK", "👍", "On my way", "Yes", "No", "Thanks"]

  private var messages: [WatchMessage] {
    receiver.messages[conversation.id] ?? []
  }

  private var outcome: WatchSendOutcome? {
    sendID.flatMap { receiver.sendOutcomes[$0] }
  }

  private var isSending: Bool {
    sendID != nil && outcome == nil
  }

  var body: some View {
    List {
      Section {
        if messages.isEmpty {
          Text("No Recent Messages")
            .foregroundStyle(.secondary)
        } else {
          ForEach(messages) { message in
            MessageRow(message: message)
          }
        }
      }

      if conversation.ref.canSend {
        Section {
          TextField("Message", text: $draft)
            .onSubmit { send(draft) }
          ForEach(Self.quickReplies, id: \.key) { reply in
            Button {
              send(String(localized: reply))
            } label: {
              Text(reply)
            }
          }
        } header: {
          Text("Reply")
        } footer: {
          SendStatus(isPhoneReachable: receiver.isPhoneReachable, isSending: isSending, outcome: outcome)
        }
        .disabled(isSending || !receiver.isPhoneReachable)
      } else {
        Section {
          Text("Replying to rooms from Apple Watch is not supported yet.")
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(conversation.name)
    .task {
      receiver.requestMessages(for: conversation.ref)
      #if DEBUG
        // CI hook (watch-simulator.yml): send a message without tapping the UI.
        if let text = UserDefaults.standard.string(forKey: "sendTestMessage") {
          send(text)
        }
      #endif
    }
    .onChange(of: outcome) { _, newOutcome in
      guard newOutcome == .queued else { return }
      draft = ""
      receiver.requestMessages(for: conversation.ref)
    }
  }

  private func send(_ text: String) {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !isSending else { return }
    sendID = receiver.send(text, to: conversation.ref)
  }
}

private struct MessageRow: View {
  let message: WatchMessage

  private var alignment: HorizontalAlignment {
    message.isOutgoing ? .trailing : .leading
  }

  var body: some View {
    VStack(alignment: alignment, spacing: 2) {
      if let senderName = message.senderName {
        Text(senderName)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Text(message.text)
        .multilineTextAlignment(message.isOutgoing ? .trailing : .leading)
      HStack(spacing: 4) {
        Text(message.date, format: .relative(presentation: .named))
        if let status = message.status {
          StatusIcon(status: status)
        }
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct StatusIcon: View {
  let status: WatchMessage.Status

  var body: some View {
    switch status {
    case .sending:
      Image(systemName: "clock")
        .accessibilityLabel(Text("Sending"))
    case .sent:
      Image(systemName: "checkmark")
        .accessibilityLabel(Text("Sent"))
    case .delivered:
      Image(systemName: "checkmark.circle.fill")
        .accessibilityLabel(Text("Delivered"))
    case .failed:
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(.red)
        .accessibilityLabel(Text("Failed"))
    }
  }
}

/// Footer under the reply controls. Mirrors the Send Message shortcut: a queued message is in
/// the radio's send queue, and its delivery shows on the message once the mesh acknowledges it.
private struct SendStatus: View {
  let isPhoneReachable: Bool
  let isSending: Bool
  let outcome: WatchSendOutcome?

  var body: some View {
    if !isPhoneReachable {
      Text("iPhone not reachable.")
    } else if isSending {
      Text("Sending…")
    } else if let outcome {
      switch outcome {
      case .queued:
        Label("Queued on the radio", systemImage: "checkmark")
      case let .failed(reason):
        Text(reason)
          .foregroundStyle(.red)
      }
    }
  }
}
