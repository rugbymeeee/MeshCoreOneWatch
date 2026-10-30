// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum Watch {
    internal enum Accessibility {
      /// Location: ContentView.swift - VoiceOver label for a channel conversation
      internal static let channel = L10n.tr("Watch", "watch.accessibility.channel", fallback: "Channel")
      /// Location: ContentView.swift - VoiceOver label for a direct message conversation
      internal static let directMessage = L10n.tr("Watch", "watch.accessibility.directMessage", fallback: "Direct Message")
      /// Location: ContentView.swift - VoiceOver label for a conversation that notifies on mentions only
      internal static let mentionsOnly = L10n.tr("Watch", "watch.accessibility.mentionsOnly", fallback: "Mentions Only")
      /// Location: ContentView.swift - VoiceOver label for a muted conversation
      internal static let muted = L10n.tr("Watch", "watch.accessibility.muted", fallback: "Muted")
      /// Location: ContentView.swift - VoiceOver label for a room conversation
      internal static let room = L10n.tr("Watch", "watch.accessibility.room", fallback: "Room")
      /// Location: ContentView.swift - VoiceOver label for the unread count badge. %d is the number of unread messages
      internal static func unreadCount(_ p1: Int) -> String {
        return L10n.tr("Watch", "watch.accessibility.unreadCount", p1, fallback: "%d unread")
      }
      /// Location: ContentView.swift - VoiceOver label for the @ badge
      internal static let unreadMention = L10n.tr("Watch", "watch.accessibility.unreadMention", fallback: "Unread mention")
    }
    internal enum Connection {
      /// Location: ContentView.swift - Radio status when the radio has no name
      internal static let connected = L10n.tr("Watch", "watch.connection.connected", fallback: "Connected")
      /// Location: ContentView.swift - Radio status while connecting
      internal static let connecting = L10n.tr("Watch", "watch.connection.connecting", fallback: "Connecting…")
      /// Location: ContentView.swift - Radio status when no radio is connected
      internal static let notConnected = L10n.tr("Watch", "watch.connection.notConnected", fallback: "Not Connected")
    }
    internal enum Home {
      /// Location: ContentView.swift - Section header for the conversation list
      internal static let conversations = L10n.tr("Watch", "watch.home.conversations", fallback: "Conversations")
      /// Location: ContentView.swift - Shown when the iPhone has no conversations
      internal static let empty = L10n.tr("Watch", "watch.home.empty", fallback: "No Conversations")
      /// Location: ContentView.swift - Button asking the iPhone for fresh data
      internal static let refresh = L10n.tr("Watch", "watch.home.refresh", fallback: "Refresh")
      /// Location: ContentView.swift - Navigation title of the home screen, the app name
      internal static let title = L10n.tr("Watch", "watch.home.title", fallback: "MeshCore One")
      internal enum Footer {
        /// Location: ContentView.swift - Home footer before any data has arrived from the iPhone
        internal static let noData = L10n.tr("Watch", "watch.home.footer.noData", fallback: "Open MeshCore One on your iPhone to connect a radio.")
        /// Location: ContentView.swift - Home footer when the iPhone is out of reach
        internal static let unreachable = L10n.tr("Watch", "watch.home.footer.unreachable", fallback: "iPhone not reachable. Showing the last update.")
      }
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
