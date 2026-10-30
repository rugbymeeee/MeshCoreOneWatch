import Foundation
import MC1WatchShared
import os
import WatchConnectivity

private let logger = Logger(subsystem: "com.mc1", category: "WatchSnapshotReceiver")

/// The watch app's link to the iPhone app: receives the published `WatchSnapshot` and asks the
/// iPhone for a fresh one.
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

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// Asks the iPhone app for a fresh snapshot, which it answers with a live message.
  func requestRefresh() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else { return }
    let message: [String: Any]
    do {
      message = try WatchRequest.snapshot.payload()
    } catch {
      logger.error("Failed to encode watch request: \(error.localizedDescription)")
      return
    }
    session.sendMessage(message, replyHandler: nil) { @Sendable error in
      logger.error("Watch refresh request failed: \(error.localizedDescription)")
    }
  }

  private func updateReachability(_ isReachable: Bool) {
    isPhoneReachable = isReachable
    // The system keeps the last context, so only ask when nothing has arrived yet.
    if isReachable, snapshot == nil {
      requestRefresh()
    }
  }

  /// Decodes off the main actor so only Sendable values cross over.
  private nonisolated func receive(_ payload: [String: Any]) {
    do {
      guard let snapshot = try WatchSnapshot(payload: payload) else { return }
      logger.info("Received watch snapshot: \(snapshot.connection.rawValue, privacy: .public), \(snapshot.conversations.count) conversations")
      Task { @MainActor in self.snapshot = snapshot }
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

  /// Answers to refresh requests, which the iPhone sends live.
  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receive(message)
  }
}
