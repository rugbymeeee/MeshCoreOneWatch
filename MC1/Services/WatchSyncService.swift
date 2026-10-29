import Foundation
import MC1Services
import OSLog
import WatchConnectivity

private let logger = Logger(subsystem: "com.mc1", category: "WatchSyncService")

/// Publishes a `WatchSnapshot` to the paired Apple Watch app through the WatchConnectivity
/// application context, which is latest-wins and reaches the watch even when its app is not running.
///
/// Does no work unless a paired watch has the app installed, so users without a watch pay nothing.
@MainActor
final class WatchSyncService: NSObject {
  /// Minimum spacing between sends. Throttles rather than debounces: the first change goes out at
  /// once, and a steady stream of changes still reaches the watch at least this often.
  static let minimumPublishInterval: Duration = .seconds(2)

  /// Called when the watch needs a fresh snapshot: session activation, the watch app becoming
  /// installed, or a refresh request from the watch. Installed by `AppState`.
  var onSnapshotNeeded: (@MainActor () -> Void)?

  /// Answers the watch's other requests (recent messages, sends). Installed by `AppState`.
  var onRequest: (@MainActor (WatchRequest) async -> WatchReply?)?

  private let session: WCSession? = WCSession.isSupported() ? .default : nil
  private let clock = ContinuousClock()
  private var publishTask: Task<Void, Never>?
  /// Builds the next snapshot; a request that arrives while a send is pending replaces it.
  private var pendingSnapshot: (@MainActor () async -> WatchSnapshot?)?
  private var lastPublishAttempt: ContinuousClock.Instant?
  private var lastPublished: WatchSnapshot?
  /// Set by a refresh request: the next snapshot also goes out as a live message, which reaches
  /// the running watch app even before `isWatchAppInstalled` reports it.
  private var answersRefreshRequest = false

  /// True when a paired watch has the app installed and the session can deliver.
  private var canPublish: Bool {
    guard let session else { return false }
    return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
  }

  func activate() {
    guard let session else { return }
    session.delegate = self
    session.activate()
  }

  /// Schedules a send of the snapshot `makeSnapshot` builds. The snapshot is built when the send
  /// fires, so it always reflects the latest data.
  func requestPublish(_ makeSnapshot: @escaping @MainActor () async -> WatchSnapshot?) {
    guard canPublish || answersRefreshRequest else { return }
    pendingSnapshot = makeSnapshot
    guard publishTask == nil else { return }
    publishTask = Task { [weak self] in
      await self?.drainPendingPublishes()
    }
  }

  private func drainPendingPublishes() async {
    while pendingSnapshot != nil {
      if let lastPublishAttempt {
        try? await clock.sleep(until: lastPublishAttempt + Self.minimumPublishInterval)
      }
      guard let makeSnapshot = pendingSnapshot else { break }
      pendingSnapshot = nil
      lastPublishAttempt = clock.now
      if let snapshot = await makeSnapshot() {
        publish(snapshot)
      }
    }
    publishTask = nil
  }

  private func publish(_ snapshot: WatchSnapshot) {
    guard let session, session.activationState == .activated else { return }
    let context: [String: Any]
    do {
      context = try snapshot.payload()
    } catch {
      logger.error("Failed to encode watch snapshot: \(error.localizedDescription)")
      return
    }

    if answersRefreshRequest {
      answersRefreshRequest = false
      if session.isReachable {
        session.sendMessage(context, replyHandler: nil) { @Sendable error in
          logger.error("Failed to answer watch refresh: \(error.localizedDescription)")
        }
      }
    }

    guard canPublish, snapshot != lastPublished else { return }
    do {
      try session.updateApplicationContext(context)
      lastPublished = snapshot
      logger.info("Published watch snapshot with \(snapshot.conversations.count) conversations")
    } catch {
      logger.error("Failed to publish watch snapshot: \(error.localizedDescription)")
    }
  }

  private func handleSessionStateChange() {
    if let session {
      logger.info(
        "Watch session: activated=\(session.activationState == .activated), paired=\(session.isPaired), appInstalled=\(session.isWatchAppInstalled)"
      )
    }
    // A reinstalled or newly paired watch starts empty, so the next send must not be deduplicated.
    lastPublished = nil
    onSnapshotNeeded?()
  }

  private func handleRequest(_ request: WatchRequest) async {
    guard case .snapshot = request else {
      if let reply = await onRequest?(request) {
        logger.info("Answering watch request \(request.logDescription, privacy: .public): \(reply.logDescription, privacy: .public)")
        sendReply(reply)
      }
      return
    }
    logger.info("Watch requested a snapshot")
    answersRefreshRequest = true
    lastPublished = nil
    onSnapshotNeeded?()
  }

  /// Sends a reply live while the watch app runs, or queues it for the next time it does.
  private func sendReply(_ reply: WatchReply) {
    guard let session, session.activationState == .activated else { return }
    let message: [String: Any]
    do {
      message = try reply.payload()
    } catch {
      logger.error("Failed to encode watch reply: \(error.localizedDescription)")
      return
    }
    if session.isReachable {
      session.sendMessage(message, replyHandler: nil) { @Sendable error in
        logger.error("Failed to send watch reply: \(error.localizedDescription)")
      }
    } else {
      session.transferUserInfo(message)
    }
  }
}

extension WatchSyncService: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: (any Error)?
  ) {
    if let error {
      logger.error("WCSession activation failed: \(error.localizedDescription)")
    }
    Task { @MainActor in handleSessionStateChange() }
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor in handleSessionStateChange() }
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    let request: WatchRequest
    do {
      guard let decoded = try WatchRequest(payload: message) else { return }
      request = decoded
    } catch {
      logger.error("Failed to decode watch request: \(error.localizedDescription)")
      return
    }
    Task { @MainActor in await handleRequest(request) }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  /// Fires when the user switches to another watch; reactivate to talk to the new one.
  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
