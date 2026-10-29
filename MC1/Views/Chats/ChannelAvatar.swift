import MC1Services
import SwiftUI

struct ChannelAvatar: View {
  @Environment(\.appTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  let channel: ChannelDTO
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(fill)

      Image(systemName: Self.symbolName(for: channel))
        .font(.system(size: size * 0.4, weight: .bold))
        .foregroundStyle(glyph)
    }
    .frame(width: size, height: size)
  }

  /// SF Symbol drawn for `channel`: public, hashtag, or private. Shared with the Apple Watch snapshot.
  static func symbolName(for channel: ChannelDTO) -> String {
    channel.isPublicChannel ? "globe" : (channel.name.hasPrefix("#") ? "number" : "lock")
  }

  private var fill: Color {
    theme.categoryAvatarColor(.channel, colorScheme: colorScheme, contrast: colorSchemeContrast)
  }

  private var glyph: Color {
    theme.avatarGlyphColor(
      forFill: fill,
      usesCategoryOverride: theme.usesCategoryAvatarOverride,
      colorScheme: colorScheme,
      contrast: colorSchemeContrast
    )
  }
}
