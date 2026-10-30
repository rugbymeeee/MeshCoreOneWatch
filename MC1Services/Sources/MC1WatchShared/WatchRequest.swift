import Foundation

/// A request the watch app sends to the iPhone app as a live WatchConnectivity message.
public enum WatchRequest: WatchConnectivityPayload, Equatable, Sendable {
  /// Send the current snapshot back.
  case snapshot

  public static let payloadKey = "watchRequest"
}
