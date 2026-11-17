import SwiftUI
import UIKit

enum Palette {
  static let ink = Color(hex: 0x2B2540)
  static let inkShadow = Color(hex: 0x1A1626)
  static let asphalt = Color(hex: 0x4E4A63)
  static let edge = Color(hex: 0x6B6784)
  static let kerb = Color(hex: 0x9C99B5)
  static let kerbLight = Color(hex: 0xC4C2D8)
  static let paper = Color(hex: 0xF4EAD0)
  static let cream = Color(hex: 0xFFF8E6)
  static let kraft = Color(hex: 0xE0CFA8)
  static let green = Color(hex: 0x3FD4A2)
  static let greenLight = Color(hex: 0x8CF2CC)
  static let greenDark = Color(hex: 0x1F9A78)
  static let coral = Color(hex: 0xD9483F)
  static let coralLight = Color(hex: 0xF27A6B)
  static let coralDark = Color(hex: 0x962A35)
  static let gold = Color(hex: 0xFFC23D)
  static let goldLight = Color(hex: 0xFFE07A)
  static let goldDark = Color(hex: 0xD98A1C)
  static let sky = Color(hex: 0x3B9BE0)
  static let skyLight = Color(hex: 0x7CC6F5)
  static let skyDark = Color(hex: 0x2468A8)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

extension Color {
  var readableText: Color {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    func linear(_ value: CGFloat) -> CGFloat {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722 >= 0.36
      ? Palette.ink : Palette.cream
  }
}

enum Lettering {
  static func title(_ size: CGFloat = 32) -> Font { .custom("Jersey10-Regular", size: size) }
  static func body(_ size: CGFloat = 18) -> Font { .custom("PixelifySans-Regular", size: size) }
  static func hud(_ size: CGFloat = 14) -> Font { body(size).weight(.semibold) }
}

struct PixelPanelShape: Shape {
  var step: CGFloat = 4
  func path(in rect: CGRect) -> Path {
    let x = rect.minX
    let y = rect.minY
    let w = rect.maxX
    let h = rect.maxY
    let c = min(step, min(rect.width, rect.height) / 2)
    let u = max(1, c / 3)
    let points = [
      CGPoint(x: x + c, y: y), CGPoint(x: w - c, y: y),
      CGPoint(x: w - u, y: y), CGPoint(x: w - u, y: y + u),
      CGPoint(x: w, y: y + u), CGPoint(x: w, y: y + c),
      CGPoint(x: w, y: h - c), CGPoint(x: w, y: h - u),
      CGPoint(x: w - u, y: h - u), CGPoint(x: w - u, y: h),
      CGPoint(x: w - c, y: h), CGPoint(x: x + c, y: h),
      CGPoint(x: x + u, y: h), CGPoint(x: x + u, y: h - u),
      CGPoint(x: x, y: h - u), CGPoint(x: x, y: h - c),
      CGPoint(x: x, y: y + c), CGPoint(x: x, y: y + u),
      CGPoint(x: x + u, y: y + u), CGPoint(x: x + u, y: y),
    ]
    return Path { path in
      path.addLines(points)
      path.closeSubpath()
    }
  }
}

struct PaperBackground: View {
  var body: some View {
    Palette.paper.overlay {
      Canvas { context, size in
        var dots = Path()
        for y in stride(from: CGFloat(0), to: size.height, by: 6) {
          for x in stride(from: Int(y / 6) % 2 == 0 ? CGFloat(0) : 3, to: size.width, by: 6) {
            dots.addRect(CGRect(x: x, y: y, width: 1, height: 1))
          }
        }
        context.fill(dots, with: .color(Palette.kraft.opacity(0.65)))
      }.accessibilityHidden(true).allowsHitTesting(false)
    }
  }
}

extension View {
  func pixelPanel(
    _ fill: Color = Palette.paper, highlight: Color? = Palette.cream,
    shade: Color? = Palette.kraft, step: CGFloat = 3,
    innerBorder: Color? = nil, shadow: Color? = Palette.inkShadow
  ) -> some View {
    background {
      ZStack {
        if let shadow { PixelPanelShape(step: step).fill(shadow).offset(x: 1, y: 1) }
        Canvas { context, size in
          let bounds = CGRect(origin: .zero, size: size)
          context.fill(PixelPanelShape(step: step).path(in: bounds), with: .color(Palette.ink))
          let inner = bounds.insetBy(dx: 1, dy: 1)
          context.fill(PixelPanelShape(step: step).path(in: inner), with: .color(fill))
          if let highlight {
            context.fill(Path(CGRect(x: 1 + step, y: 1, width: max(0, size.width - 2 - 2 * step), height: 1)), with: .color(highlight))
          }
          if let shade {
            context.fill(Path(CGRect(x: 1 + step, y: size.height - 2, width: max(0, size.width - 2 - 2 * step), height: 1)), with: .color(shade))
          }
          if let innerBorder {
            context.stroke(PixelPanelShape(step: step).path(in: bounds.insetBy(dx: 1.5, dy: 1.5)), with: .color(innerBorder), lineWidth: 1)
          }
        }
      }.allowsHitTesting(false)
    }
    .contentShape(PixelPanelShape(step: step))
  }
}

struct PaperButtonStyle: ButtonStyle {
  var color: Color = Palette.green
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    let highlight =
      color == Palette.gold
      ? Palette.goldLight
      : color == Palette.green
        ? Palette.greenLight : color == Palette.coral ? Palette.coralLight : Palette.cream
    let shade =
      color == Palette.gold
      ? Palette.goldDark
      : color == Palette.green
        ? Palette.greenDark : color == Palette.coral ? Palette.coralDark : Palette.kraft
    configuration.label.font(Lettering.title(24))
      .multilineTextAlignment(.center)
      .foregroundStyle(enabled ? color.readableText : Palette.ink.opacity(0.55))
      .padding(.horizontal, 9)
      .frame(maxWidth: .infinity, minHeight: 54)
      .pixelPanel(enabled ? color : Palette.kerbLight, highlight: highlight, shade: shade, step: 6)
      .offset(y: configuration.isPressed ? 2 : 0)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

struct PaperButton: View {
  let text: String
  var color: Color
  var enabled: Bool
  let action: () -> Void
  @Environment(\.modalAction) private var modalAction

  init(
    _ text: String, color: Color = Palette.green, enabled: Bool = true, action: @escaping () -> Void
  ) {
    self.text = text
    self.color = color
    self.enabled = enabled
    self.action = action
  }

  var body: some View {
    Button {
      modalAction(action)
    } label: {
      Text(text)
    }
    .buttonStyle(PaperButtonStyle(color: color)).disabled(!enabled)
  }
}

struct CraftChip<Label: View>: View {
  var selected: Bool
  var fill: Color? = nil
  var action: () -> Void
  @ViewBuilder var label: () -> Label
  var body: some View {
    Button(action: action) {
      label().font(Lettering.hud())
        .padding(.horizontal, 7).padding(.vertical, 4)
        .frame(minHeight: 44)
        .foregroundStyle(selected ? Palette.ink : Palette.cream)
        .pixelPanel(
          fill ?? (selected ? Palette.goldLight : Palette.asphalt),
          step: 4)
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct Artwork: View {
  let name: String
  var size: CGFloat
  init(_ name: String, size: CGFloat = 30) {
    self.name = name
    self.size = size
  }
  var body: some View {
    Image(name).interpolation(.none).resizable().scaledToFit()
      .frame(width: size, height: size).accessibilityHidden(true)
  }
}

struct WalkerPortrait: View {
  let walker: Walker
  let skills: Set<String>
  let size: CGFloat
  var child = false
  var body: some View {
    ZStack(alignment: .topTrailing) {
      Artwork(walker.sprite, size: size)
      if walker.kind == "phone" && !skills.contains("phone_away") {
        Artwork("phone", size: size * 0.38).offset(x: size * 0.1, y: size * 0.35)
          .accessibilityHidden(false).accessibilityLabel("con celular")
      }
      if walker.kind == "headphones" && !skills.contains("headphones_off") {
        Artwork("headphones", size: size * 0.62).offset(x: -size * 0.19, y: -size * 0.14)
          .accessibilityHidden(false).accessibilityLabel("con audífonos")
      }
      if child {
        Image(systemName: "figure.walk").font(.system(size: size * 0.26, weight: .bold))
          .foregroundStyle(Palette.ink).padding(2).background(Palette.goldLight)
      }
    }
  }
}

struct ToolArtwork: View {
  let id: String
  var body: some View {
    if id == "speed_zone" {
      Canvas { context, size in
        let u = size.width / 30
        let violet = Color(hex: 0x9333EA)
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
          context.fill(
            Path(CGRect(x: x * u, y: y * u, width: w * u, height: h * u)), with: .color(color))
        }
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: Color) {
          context.fill(
            Path(
              ellipseIn: CGRect(x: (x - r) * u, y: (y - r) * u, width: 2 * r * u, height: 2 * r * u)
            ), with: .color(color))
        }
        context.fill(
          Path(ellipseIn: CGRect(x: u, y: 8 * u, width: 25 * u, height: 15 * u)),
          with: .color(violet.opacity(0.22)))
        rect(3, 15, 19, 7, Color(hex: 0x7E22CE))
        rect(8, 11, 9, 5, Color(hex: 0xD8B4FE))
        circle(8, 23, 2.5, Palette.ink)
        circle(19, 23, 2.5, Palette.ink)
        circle(24, 8, 6, violet)
        circle(24, 8, 4.7, Color(hex: 0xF3E8FF))
        let hands = Path { p in
          p.move(to: CGPoint(x: 24 * u, y: 4 * u))
          p.addLine(to: CGPoint(x: 24 * u, y: 8 * u))
          p.addLine(to: CGPoint(x: 27 * u, y: 9 * u))
        }
        context.stroke(hands, with: .color(violet), lineWidth: 1.5 * u)
      }.frame(width: 30, height: 30).accessibilityHidden(true)
    } else {
      Artwork(
        [
          "look": "icon_look", "visible": "icon_reflector", "lighting": "icon_streetlamp",
          "car_lights": "icon_headlights", "escort": "icon_escort", "phone_away": "icon_phone_away",
          "headphones_off": "icon_headphones_off", "crosswalk": "icon_crosswalk",
        ][id] ?? "icon_crosswalk")
    }
  }
}

struct PaperStars: View {
  let count: Int
  var size: CGFloat = 18
  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<3) { index in
        Image("star").interpolation(.none).resizable().scaledToFit()
          .frame(width: size, height: size).opacity(index < count ? 1 : 0.25)
          .accessibilityLabel(index < count ? "Estrella obtenida" : "Estrella pendiente")
      }
    }
  }
}
