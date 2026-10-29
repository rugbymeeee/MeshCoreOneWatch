import UserNotifications

public extension NotificationService {
  @MainActor
  struct SystemOperations {
    public let setBadgeCount: @MainActor (Int) async throws -> Void
    public let deliveredRequests: @MainActor () async -> [UNNotificationRequest]
    public let removeDeliveredNotifications: @MainActor ([String]) -> Void

    public init(
      setBadgeCount: @escaping @MainActor (Int) async throws -> Void,
      deliveredRequests: @escaping @MainActor () async -> [UNNotificationRequest],
      removeDeliveredNotifications: @escaping @MainActor ([String]) -> Void
    ) {
      self.setBadgeCount = setBadgeCount
      self.deliveredRequests = deliveredRequests
      self.removeDeliveredNotifications = removeDeliveredNotifications
    }

    public static let live = Self(
      setBadgeCount: { count in
        // watchOS apps have no icon badge.
        #if os(watchOS)
          _ = count
        #else
          try await UNUserNotificationCenter.current().setBadgeCount(count)
        #endif
      },
      deliveredRequests: { await UNUserNotificationCenter.current().deliveredNotifications().map(\.request) },
      removeDeliveredNotifications: { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: $0) }
    )
  }
}
