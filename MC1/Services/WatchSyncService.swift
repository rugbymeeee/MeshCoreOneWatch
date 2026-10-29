import Foundation
import MC1Services
import OSLog
import WatchConnectivity

/// Publishes a `WatchSnapshot` to the paired Apple Watch app through the WatchConnectivity
/// application context, which is latest-wins and reaches the watch even when its app is not running.
///
/// Does no work unless a paired watch has the app installed, so users without a watch pay nothing.
@MainActor
final class WatchSyncService: NSObject {
  private let logger = Logger(subsystem: "com.mc1", category: "WatchSyncService")

  /// Coalesces bursts of conversation changes (a sync, a flood of messages) into one send.
  static let publishDelay: Duration = .seconds(1)

  /// Called when the watch needs a fresh snapshot: session activation or the watch app
  /// becoming installed. Installed by `AppState`.
  var onSnapshotNeeded: (@MainActor () -> Void)?

  private let session: WCSession? = WCSession.isSupported() ? .default : nil
  private var publishTask: Task<Void, Never>?
  private var lastPublished: WatchSnapshot?

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

  /// Schedules a send of the snapshot `makeSnapshot` builds, replacing any pending send.
  func requestPublish(_ makeSnapshot: @escaping @MainActor () async -> WatchSnapshot?) {
    guard canPublish else { return }
    publishTask?.cancel()
    publishTask = Task { [weak self] in
      try? await Task.sleep(for: Self.publishDelay)
      guard !Task.isCancelled, let snapshot = await makeSnapshot(), !Task.isCancelled else { return }
      self?.publish(snapshot)
    }
  }

  private func publish(_ snapshot: WatchSnapshot) {
    guard let session, canPublish, snapshot != lastPublished else { return }
    do {
      try session.updateApplicationContext(snapshot.applicationContext())
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
}

extension WatchSyncService: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: (any Error)?
  ) {
    if let error {
      Logger(subsystem: "com.mc1", category: "WatchSyncService")
        .error("WCSession activation failed: \(error.localizedDescription)")
    }
    Task { @MainActor in handleSessionStateChange() }
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor in handleSessionStateChange() }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  /// Fires when the user switches to another watch; reactivate to talk to the new one.
  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
