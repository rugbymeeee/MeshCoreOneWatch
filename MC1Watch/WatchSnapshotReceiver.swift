import Foundation
import MC1Services
import os
import WatchConnectivity

private let logger = Logger(subsystem: "com.mc1", category: "WatchSnapshotReceiver")

/// Receives the `WatchSnapshot` the iPhone app publishes over WatchConnectivity.
///
/// The system persists the last application context, so the most recent snapshot is
/// available at launch even when the iPhone is out of range.
@Observable
@MainActor
final class WatchSnapshotReceiver: NSObject {
  /// Latest snapshot from the iPhone; nil until one has ever been received.
  private(set) var snapshot: WatchSnapshot?

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// Decodes off the main actor so only the Sendable snapshot crosses over.
  private nonisolated func receive(_ context: [String: Any]) {
    let decoded: WatchSnapshot?
    do {
      decoded = try WatchSnapshot(applicationContext: context)
    } catch {
      logger.error("Failed to decode watch snapshot: \(error.localizedDescription)")
      return
    }
    guard let decoded else { return }
    Task { @MainActor in snapshot = decoded }
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
    receive(session.receivedApplicationContext)
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receive(applicationContext)
  }
}
