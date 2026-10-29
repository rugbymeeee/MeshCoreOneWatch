import Foundation

/// An sRGB color the iPhone resolved from its theme, so the watch draws the same colors without
/// carrying the theme engine.
public struct WatchColor: Codable, Hashable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double
  public let opacity: Double

  public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
    self.red = red
    self.green = green
    self.blue = blue
    self.opacity = opacity
  }
}

/// A conversation avatar as the iPhone's Chats list draws it: initials or a symbol on a themed circle.
public struct WatchAvatar: Codable, Equatable, Sendable {
  public enum Glyph: Codable, Equatable, Sendable {
    /// A contact's initials, or the emoji in their name.
    case initials(String)
    /// An SF Symbol name, for channels and rooms.
    case symbol(String)
  }

  public let glyph: Glyph
  public let fill: WatchColor
  public let glyphColor: WatchColor

  public init(glyph: Glyph, fill: WatchColor, glyphColor: WatchColor) {
    self.glyph = glyph
    self.fill = fill
    self.glyphColor = glyphColor
  }
}

/// The iPhone theme's colors for the watch, resolved for a dark appearance since watchOS is always dark.
public struct WatchAppearance: Codable, Equatable, Sendable {
  /// Tint for buttons and links; nil keeps the system tint, as the iPhone's default theme does.
  public let tint: WatchColor?
  /// Screen background of themes that paint one; nil keeps the system black.
  public let canvas: WatchColor?
  /// Row background of themes that paint one; nil keeps the system row platter.
  public let card: WatchColor?
  public let outgoingBubble: WatchColor
  public let outgoingText: WatchColor
  public let incomingBubble: WatchColor

  public init(
    tint: WatchColor?,
    canvas: WatchColor?,
    card: WatchColor?,
    outgoingBubble: WatchColor,
    outgoingText: WatchColor,
    incomingBubble: WatchColor
  ) {
    self.tint = tint
    self.canvas = canvas
    self.card = card
    self.outgoingBubble = outgoingBubble
    self.outgoingText = outgoingText
    self.incomingBubble = incomingBubble
  }
}
