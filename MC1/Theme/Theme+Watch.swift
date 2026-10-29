import MC1Services
import SwiftUI
import UIKit

/// Resolves the theme for the Apple Watch app, which always renders dark. The watch draws these
/// colors as they are, so a contact, channel, or sender looks the same on both devices.
@MainActor
extension Theme {
  private static let watchColorScheme: ColorScheme = .dark
  private static let watchContrast: ColorSchemeContrast = .standard

  var watchAppearance: WatchAppearance {
    WatchAppearance(
      tint: chromeTint.map(watchColor),
      canvas: surfaces.map { watchColor($0.canvas) },
      card: surfaces?.card.map(watchColor),
      outgoingBubble: watchColor(accentColor),
      outgoingText: watchColor(outgoingTextColor),
      incomingBubble: watchColor(incomingBubbleColor)
    )
  }

  /// The avatar the Chats list draws for `conversation`, with the same glyph and colors.
  func watchAvatar(for conversation: Conversation) -> WatchAvatar {
    let glyph: WatchAvatar.Glyph
    let fill: Color
    let usesCategoryOverride: Bool
    switch conversation {
    case let .direct(contact):
      glyph = .initials(ContactAvatar.initials(for: contact.displayName))
      fill = identityColor(forName: contact.displayName, colorScheme: Self.watchColorScheme, contrast: Self.watchContrast)
      usesCategoryOverride = false
    case let .channel(channel):
      glyph = .symbol(ChannelAvatar.symbolName(for: channel))
      fill = categoryAvatarColor(.channel, colorScheme: Self.watchColorScheme, contrast: Self.watchContrast)
      usesCategoryOverride = usesCategoryAvatarOverride
    case .room:
      glyph = .symbol(NodeAvatar.iconName(for: .roomServer))
      fill = categoryAvatarColor(.room, colorScheme: Self.watchColorScheme, contrast: Self.watchContrast)
      usesCategoryOverride = usesCategoryAvatarOverride
    }
    let glyphColor = avatarGlyphColor(
      forFill: fill,
      usesCategoryOverride: usesCategoryOverride,
      colorScheme: Self.watchColorScheme,
      contrast: Self.watchContrast
    )
    return WatchAvatar(glyph: glyph, fill: watchColor(fill), glyphColor: watchColor(glyphColor))
  }

  /// A channel sender's identity color, as the chat timeline draws their name.
  func watchIdentityColor(forName name: String) -> WatchColor {
    watchColor(identityColor(forName: name, colorScheme: Self.watchColorScheme, contrast: Self.watchContrast))
  }

  private func watchColor(_ color: Color) -> WatchColor {
    let traits = Self.traitCollection(colorScheme: Self.watchColorScheme, contrast: Self.watchContrast)
    let resolved = UIColor(color).resolvedColor(with: traits)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    _ = resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return WatchColor(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
  }
}
