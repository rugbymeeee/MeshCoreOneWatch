import Foundation
import MC1Services
import os
import WatchConnectivity

private let logger = Logger(subsystem: "com.mc1", category: "WatchSnapshotReceiver")

/// The watch app's link to the iPhone app: receives the published `WatchSnapshot`, and sends
/// requests for a conversation's messages and for messages typed on the watch.
///
/// The system persists the last application context, so the most recent snapshot is
/// available at launch even when the iPhone is out of range.
@Observable
@MainActor
final class WatchSnapshotReceiver: NSObject {
  /// Latest snapshot from the iPhone; nil until one has ever been received.
  private(set) var snapshot: WatchSnapshot?

  /// Whether the iPhone can be reached right now. When false, `snapshot` may be out of date.
  private(set) var isPhoneReachable = false

  /// Latest messages per conversation id, oldest first.
  private(set) var messages: [UUID: [WatchMessage]] = [:]

  /// Outcome of each message sent from the watch, by request id; absent while in flight.
  private(set) var sendOutcomes: [UUID: WatchSendOutcome] = [:]

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// Asks the iPhone app for a fresh snapshot, which it answers with a live message.
  func requestRefresh() {
    sendRequest(.snapshot)
  }

  /// Asks the iPhone app for the latest messages of a conversation.
  func requestMessages(for conversation: WatchConversationRef) {
    sendRequest(.recentMessages(conversation))
  }

  /// Sends `text` to a conversation through the iPhone app. Returns the request id whose
  /// outcome lands in `sendOutcomes`, or nil when the iPhone cannot be reached.
  func send(_ text: String, to conversation: WatchConversationRef) -> UUID? {
    let id = UUID()
    let isSent = sendRequest(.send(id: id, conversation: conversation, text: text)) { [weak self] reason in
      self?.sendOutcomes[id] = .failed(reason: reason)
    }
    return isSent ? id : nil
  }

  @discardableResult
  private func sendRequest(_ request: WatchRequest, onFailure: (@MainActor @Sendable (String) -> Void)? = nil) -> Bool {
    guard WCSession.isSupported() else { return false }
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else { return false }
    let message: [String: Any]
    do {
      message = try request.payload()
    } catch {
      logger.error("Failed to encode watch request: \(error.localizedDescription)")
      return false
    }
    session.sendMessage(message, replyHandler: nil) { @Sendable error in
      logger.error("Watch request failed: \(error.localizedDescription)")
      let reason = error.localizedDescription
      Task { @MainActor in onFailure?(reason) }
    }
    return true
  }

  private func updateReachability(_ isReachable: Bool) {
    isPhoneReachable = isReachable
    // The system keeps the last context, so only ask when nothing has arrived yet.
    if isReachable, snapshot == nil {
      requestRefresh()
    }
  }

  private func apply(_ reply: WatchReply) {
    logger.info("Received iPhone reply: \(reply.logDescription, privacy: .public)")
    switch reply {
    case let .recentMessages(conversation, conversationMessages):
      messages[conversation.id] = conversationMessages
    case let .sendResult(id, outcome):
      sendOutcomes[id] = outcome
    }
  }

  /// Decodes off the main actor so only Sendable values cross over.
  private nonisolated func receive(_ payload: [String: Any]) {
    do {
      if let snapshot = try WatchSnapshot(payload: payload) {
        logger.info("Received watch snapshot: \(snapshot.connection.rawValue, privacy: .public), \(snapshot.conversations.count) conversations")
        Task { @MainActor in self.snapshot = snapshot }
      } else if let reply = try WatchReply(payload: payload) {
        Task { @MainActor in apply(reply) }
      }
    } catch {
      logger.error("Failed to decode iPhone payload: \(error.localizedDescription)")
    }
  }
}

extension WatchSnapshotReceiver: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: (any Error)?
  ) {
    if let error {
      logger.error("WCSession activation failed: \(error.localizedDescription)")
    }
    logger.info("Watch session: activated=\(activationState == .activated), companionAppInstalled=\(session.isCompanionAppInstalled)")
    receive(session.receivedApplicationContext)
    let isReachable = session.isReachable
    Task { @MainActor in updateReachability(isReachable) }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    let isReachable = session.isReachable
    Task { @MainActor in updateReachability(isReachable) }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receive(applicationContext)
  }

  /// Live replies and refresh answers from the iPhone.
  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receive(message)
  }

  /// Replies the iPhone queued while this app was not running.
  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    receive(userInfo)
  }
}
