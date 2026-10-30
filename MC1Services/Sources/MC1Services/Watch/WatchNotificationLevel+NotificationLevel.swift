import MC1WatchShared

public extension WatchNotificationLevel {
  /// The watch's copy of a conversation's notification level.
  init(_ level: NotificationLevel) {
    switch level {
    case .muted: self = .muted
    case .mentionsOnly: self = .mentionsOnly
    case .all: self = .all
    }
  }
}
