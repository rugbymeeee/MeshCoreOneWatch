import Foundation

/// A conversation's notification level as the watch shows it. Mirrors `NotificationLevel`, which
/// lives in MC1Services and so is not available to the watch app.
public enum WatchNotificationLevel: String, Codable, Sendable {
  case muted
  case mentionsOnly
  case all

  /// SF Symbol name for this notification level, the same one the iPhone draws.
  public var iconName: String {
    switch self {
    case .muted: "bell.slash"
    case .mentionsOnly: "at"
    case .all: "bell.fill"
    }
  }
}
