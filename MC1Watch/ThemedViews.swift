import MC1Services
import SwiftUI

extension Color {
  init(_ color: WatchColor) {
    self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.opacity)
  }
}

/// A conversation avatar as the iPhone draws it: initials or a symbol on a themed circle.
struct AvatarView: View {
  let avatar: WatchAvatar?
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(avatar.map { Color($0.fill) } ?? Color.gray)
      glyph
        .foregroundStyle(avatar.map { Color($0.glyphColor) } ?? Color.white)
    }
    .frame(width: size, height: size)
    .accessibilityElement(children: .ignore)
  }

  @ViewBuilder
  private var glyph: some View {
    switch avatar?.glyph {
    case let .initials(initials):
      Text(initials)
        .font(.system(size: size * 0.4, weight: .semibold))
    case let .symbol(name):
      Image(systemName: name)
        .font(.system(size: size * 0.4, weight: .bold))
    case nil:
      Image(systemName: "person.fill")
        .font(.system(size: size * 0.4, weight: .bold))
    }
  }
}

/// Paints the iPhone theme's screen background and tint, when the theme has them.
struct ThemedScreen: ViewModifier {
  let appearance: WatchAppearance?

  func body(content: Content) -> some View {
    if let canvas = appearance?.canvas {
      content
        .containerBackground(Color(canvas), for: .navigation)
        .tint(appearance?.tint.map { Color($0) })
    } else {
      content
        .tint(appearance?.tint.map { Color($0) })
    }
  }
}

/// Row background of themes that paint card rows; the system platter otherwise.
struct ThemedRow: ViewModifier {
  let appearance: WatchAppearance?

  func body(content: Content) -> some View {
    if let card = appearance?.card {
      content
        .listRowBackground(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(card)))
    } else {
      content
    }
  }
}

extension View {
  func themedScreen(_ appearance: WatchAppearance?) -> some View {
    modifier(ThemedScreen(appearance: appearance))
  }

  func themedRow(_ appearance: WatchAppearance?) -> some View {
    modifier(ThemedRow(appearance: appearance))
  }
}
