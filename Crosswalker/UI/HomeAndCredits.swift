import SwiftUI
import UIKit

private enum MenuColors {
    static let ink = Color(hex: 0x2B2540)
    static let shadow = Color(hex: 0x1A1626)
    static let asphalt = Color(hex: 0x4E4A63)
    static let asphaltEdge = Color(hex: 0x6B6784)
    static let cream = Color(hex: 0xF4EAD0)
    static let creamLight = Color(hex: 0xFFF8E6)
    static let creamDark = Color(hex: 0xE0CFA8)
    static let taxi = Color(hex: 0xFFC23D)
    static let taxiLight = Color(hex: 0xFFE07A)
    static let taxiDark = Color(hex: 0xD98A1C)
    static let skyLight = Color(hex: 0x7CC6F5)
    static let brickLight = Color(hex: 0xF27A6B)
}

private struct MenuPanel: View {
    let face: Color
    var highlight = MenuColors.creamLight
    var shade = MenuColors.creamDark
    var corner: CGFloat = 3
    var shadow = false

    var body: some View {
        Canvas { context, size in
            let width = size.width, height = size.height
            guard width > 8, height > 8 else { return }
            let depth: CGFloat = shadow ? 2 : 0
            func panel(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
                Path { p in
                    p.move(to: CGPoint(x: x + r, y: y))
                    p.addLines([
                        CGPoint(x: x + w - r, y: y),
                        CGPoint(x: x + w - r, y: y + r),
                        CGPoint(x: x + w, y: y + r),
                        CGPoint(x: x + w, y: y + h - r),
                        CGPoint(x: x + w - r, y: y + h - r),
                        CGPoint(x: x + w - r, y: y + h),
                        CGPoint(x: x + r, y: y + h),
                        CGPoint(x: x + r, y: y + h - r),
                        CGPoint(x: x, y: y + h - r),
                        CGPoint(x: x, y: y + r),
                        CGPoint(x: x + r, y: y + r),
                        CGPoint(x: x + r, y: y)
                    ])
                    p.closeSubpath()
                }
            }
            if shadow {
                context.fill(panel(0, depth, width, height - depth, corner), with: .color(MenuColors.shadow))
            }
            let frame = panel(0, 0, width, height - depth, corner)
            context.fill(frame, with: .color(MenuColors.ink))
            let surface = panel(1.5, 1.5, width - 3, height - depth - 3, max(1, corner - 1))
            context.fill(surface, with: .color(face))
            var edges = context
            edges.clip(to: surface)
            edges.fill(Path(CGRect(x: 1.5, y: 1.5, width: width - 3, height: 2)), with: .color(highlight))
            edges.fill(Path(CGRect(x: 1.5, y: height - depth - 3.5, width: width - 3, height: 2)), with: .color(shade))
        }
        .accessibilityHidden(true)
    }
}

private struct MenuGamelikeButton: ButtonStyle {
    let primary: Bool
    let height: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        let face = primary ? MenuColors.taxi : MenuColors.cream
        let light = primary ? MenuColors.taxiLight : MenuColors.creamLight
        let dark = primary ? MenuColors.taxiDark : MenuColors.creamDark
        return configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: height - 2)
            .background {
                MenuPanel(face: face, highlight: light, shade: dark)
            }
            .offset(y: configuration.isPressed ? 2 : 0)
            .padding(.bottom, 2)
            .background(alignment: .bottom) {
                MenuPanel(face: dark, highlight: dark, shade: dark, shadow: true)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct MenuActionButton: View {
    let title: String
    var icon: String? = nil
    var badgeColor: Color = MenuColors.creamLight
    var primary = false
    var height: CGFloat = 54
    var hint = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Text(icon)
                        .font(.custom("Jersey10-Regular", size: 18))
                        .frame(width: 28, height: 28)
                        .background { MenuPanel(face: badgeColor, highlight: MenuColors.creamLight, shade: badgeColor) }
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.custom("Jersey10-Regular", size: 24))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(MenuColors.ink)
        }
        .buttonStyle(MenuGamelikeButton(primary: primary, height: height))
        .accessibilityHint(hint)
    }
}

@MainActor
struct HomeScreen: View {
    @ObservedObject var session: Session

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MenuStreetAnimation()
                    .accessibilityHidden(true)
                LinearGradient(stops: [
                    .init(color: MenuColors.shadow.opacity(0.30), location: 0),
                    .init(color: .clear, location: 0.28),
                    .init(color: .clear, location: 0.68),
                    .init(color: MenuColors.shadow.opacity(0.84), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                ScrollView {
                    VStack(spacing: 0) {
                        MenuLogo(width: max(1, min(340, geometry.size.width - 40)))
                        Spacer(minLength: 125)
                        VStack(spacing: 9) {
                            MenuActionButton(title: "JUGAR", icon: "▶", primary: true, height: 62, hint: "Elegir nivel") {
                                session.beep()
                                session.navigate(.map)
                            }
                            HStack(spacing: 9) {
                                MenuActionButton(title: "AJUSTES", icon: "⚙", badgeColor: MenuColors.skyLight) {
                                    session.beep()
                                    session.dialog = "settings"
                                }
                                MenuActionButton(title: "LOGROS", icon: "★", badgeColor: MenuColors.taxiLight) {
                                    session.beep()
                                    session.dialog = "achievements"
                                }
                            }
                            MenuActionButton(title: "REINICIAR PROGRESO", icon: "↻", badgeColor: MenuColors.brickLight) {
                                session.beep()
                                session.dialog = "resetProgress"
                            }
                        }.frame(maxWidth: 400)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .disabled(session.transitioning)
                .accessibilityHidden(session.transitioning)
            }
            .clipped()
        }
    }
}

private struct MenuLogo: View {
    let width: CGFloat

    var body: some View {
        let letter = min(66, width * 0.205)
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                zebra
                Text("CROSS")
                    .foregroundStyle(MenuColors.creamLight)
                    .frame(height: letter * 0.80)
                zebra
            }
            Text("WALKER")
                .foregroundStyle(MenuColors.taxiLight)
                .frame(height: letter * 0.84)
        }
        .font(.custom("Jersey10-Regular", size: letter))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: width)
        .background {
            MenuPanel(face: MenuColors.ink, highlight: MenuColors.asphaltEdge, shade: MenuColors.shadow, corner: 8)
                .overlay { MenuPanelBorder(corner: 7).strokeBorder(MenuColors.asphalt, lineWidth: 1).padding(3) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Crosswalker")
    }

    private var zebra: some View {
        VStack(spacing: 4) {
            ForEach(0..<3) { _ in Rectangle().fill(MenuColors.creamLight).frame(width: 24, height: 4) }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MenuPanelBorder: InsettableShape {
    let corner: CGFloat
    var insetAmount: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        return RoundedRectangle(cornerRadius: corner).path(in: r)
    }
    func inset(by amount: CGFloat) -> Self { .init(corner: corner, insetAmount: insetAmount + amount) }
}

private enum MenuStreetScene: Int, CaseIterable {
    case barrio, campusRain, cityNight
}

private struct MenuStreetAnimation: View {
    var cycleScenes = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { frame in
            let elapsed = max(0, frame.date.timeIntervalSince(started))
            Canvas(opaque: true) { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: 12))
                let scenes = MenuStreetScene.allCases
                let number = cycleScenes ? Int(elapsed / 12) : 0
                let scene = scenes[number % scenes.count]
                context.withCGContext { cg in
                    cg.interpolationQuality = .none
                    cg.setShouldAntialias(false)
                    let scale = size.width / 360
                    cg.scaleBy(x: scale, y: scale)
                    let height = size.height / scale
                    if number > 0 && phase < 1.8 {
                        let fade = phase / 1.8
                        let previous = scenes[(number + scenes.count - 1) % scenes.count]
                        MenuStreetPainter(context: cg, height: height, time: phase).draw(previous)
                        cg.saveGState()
                        cg.setAlpha(fade * fade * (3 - 2 * fade))
                        cg.beginTransparencyLayer(auxiliaryInfo: nil)
                        MenuStreetPainter(context: cg, height: height, time: phase).draw(scene)
                        cg.endTransparencyLayer()
                        cg.restoreGState()
                    } else {
                        MenuStreetPainter(context: cg, height: height, time: phase).draw(scene)
                    }
                }
            }
        }
    }
}

private struct MenuStreetPainter {
    let context: CGContext
    let height: CGFloat
    let time: CGFloat
    let width: CGFloat = 360
    private static let crossings: [CGFloat] = [68, 180, 288]
    private static let walkers: [(name: String, delay: CGFloat, approach: CGFloat)] = [
        ("walker_coral", 0.25, -25), ("walker_green", 0.8, 16), ("walker_rust", 1.35, 25)
    ]
    private static let sprites: [String: CGImage] = {
        let buildings = ["ground_grass", "ground_walk", "ground_road", "house", "tree", "tree_autumn",
            "decor_fence_barrio", "decor_mailbox_barrio", "car_coral", "car_yellow",
            "decor_building_campus", "decor_bikerack_campus", "decor_building_city", "decor_busstop_city"]
        let pedestrians = walkers.flatMap { walker in
            [walker.name] + (0...2).map { "\(walker.name)_w\($0)" }
        }
        return Dictionary(uniqueKeysWithValues: (buildings + pedestrians).compactMap { name in
            UIImage(named: name)?.cgImage.map { (name, $0) }
        })
    }()

    private func rgb(_ value: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: alpha)
    }

    private func paint(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UInt32, alpha: CGFloat = 1) {
        context.setFillColor(rgb(color, alpha: alpha))
        context.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private func bitmap(_ image: CGImage, _ rect: CGRect, alpha: CGFloat = 1) {
        context.saveGState()
        context.setAlpha(alpha)
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private func sprite(_ name: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        guard let art = Self.sprites[name] else { return }
        let factor = min(w / CGFloat(art.width), h / CGFloat(art.height))
        let dw = CGFloat(art.width) * factor, dh = CGFloat(art.height) * factor
        bitmap(art, CGRect(x: (x + (w - dw) / 2).rounded(), y: (y + h - dh).rounded(),
                           width: max(1, dw.rounded()), height: max(1, dh.rounded())))
    }

    private func tile(_ name: String, _ top: CGFloat, _ bottom: CGFloat, left: CGFloat = 0, tileWidth: CGFloat = 360) {
        guard bottom > top, let art = Self.sprites[name] else { return }
        context.saveGState()
        context.clip(to: CGRect(x: left, y: top, width: tileWidth, height: bottom - top))
        context.translateBy(x: 0, y: top.rounded(.towardZero) + 24)
        context.scaleBy(x: 1, y: -1)
        context.draw(art, in: CGRect(x: 0, y: 0, width: 24, height: 24), byTiling: true)
        context.restoreGState()
    }

    func draw(_ scene: MenuStreetScene) {
        let roadTop = height * 0.44, roadBottom = height * 0.64
        let median = (roadTop + roadBottom) / 2
        let plazaDepth = min(105, roadTop * 0.36)
        let plazaTop = roadTop - 24 - plazaDepth
        let fountain = plazaTop + plazaDepth * 0.48
        paint(0, 0, width, height, 0x327B69)
        tile("ground_grass", 0, height)
        tile("ground_walk", fountain, roadTop, left: 164, tileWidth: 32)
        paint(132, plazaTop, 96, plazaDepth * 0.77, 0x297C6C)
        tile("ground_walk", plazaTop + 3, plazaTop + plazaDepth * 0.72, left: 136, tileWidth: 88)
        paint(158, fountain - 17, 44, 19, 0x2B2540)
        paint(155, fountain - 13, 50, 10, 0x2B2540)
        paint(158, fountain - 12, 44, 8, 0x7185A3)
        paint(161, fountain - 15, 38, 9, 0x2468A8)
        paint(165, fountain - 13, 30, 5, 0x3B9BE0)
        paint(178, fountain - 19, 4, 10, 0xE0CFA8)
        paint(175, fountain - 21, 10, 3, 0xFFF8E6)
        let spray = CGFloat(Int(time * 4) % 3)
        paint(171 - spray, fountain - 18 + spray, 2, 2, 0x7CC6F5)
        paint(188 + spray, fountain - 18 + spray, 2, 2, 0x7CC6F5)
        paint(166, fountain - 9, 8, 1, 0x7CC6F5)
        paint(186, fountain - 11, 7, 1, 0x7CC6F5)

        let garden = roadTop - 155
        if garden > 65 {
            for left in [CGFloat(28), 258] {
                paint(left + 3, garden + 22, 73, 17, 0x278A76)
                paint(left, garden + 20, 73, 15, 0x3E705C)
                for flower in 0...8 {
                    let x = left + 5 + CGFloat(flower * 8), y = garden + 23 + CGFloat(flower % 2 * 4)
                    paint(x - 1, y + 2, 6, 5, 0x61AE7D)
                    paint(x, y, 4, 3, flower % 2 == 0 ? 0xFFE07A : 0xF27A6B)
                }
            }
        }
        tile("ground_walk", roadTop - 24, roadTop)
        tile("ground_road", roadTop, roadBottom)
        tile("ground_walk", roadBottom, roadBottom + 24)
        for column in stride(from: 12, through: 336, by: 30) {
            let x = CGFloat(column)
            if !Self.crossings.contains(where: { x < $0 + 20 && x + 16 > $0 - 20 }) {
                paint(x, median, 16, 2, 0xA09CCA)
            }
        }
        for center in Self.crossings {
            let interval = (roadBottom - roadTop) / 8
            for row in 0..<8 {
                paint(center - 19, roadTop + (CGFloat(row) + 0.2) * interval, 38, interval * 0.55, 0xFFF8E6)
            }
        }
        switch scene {
        case .barrio:
            sprite("house", 25, roadTop - 127, 86, 103)
            sprite("house", 243, roadTop - 118, 89, 94)
            sprite("decor_mailbox_barrio", 81, roadTop - 39, 35, 17)
            sprite("decor_fence_barrio", 13, roadBottom + 27, 69, 23)
        case .campusRain:
            sprite("decor_building_campus", 16, roadTop - 154, 108, 130)
            sprite("decor_building_campus", 244, roadTop - 139, 94, 115)
            sprite("decor_bikerack_campus", 23, roadBottom + 20, 68, 34)
        case .cityNight:
            sprite("decor_building_city", 5, roadTop - 170, 125, 147)
            sprite("decor_building_city", 225, roadTop - 174, 130, 150)
            sprite("decor_busstop_city", 25, roadBottom + 12, 68, 57)
        }
        sprite("tree", 117, roadTop - 87, 35, 62)
        sprite("tree_autumn", 197, roadTop - 83, 43, 58)
        sprite("tree", 296, roadBottom + 28, 45, 67)
        car("car_coral", 0, (roadTop + median) / 2, reverse: false)
        car("car_yellow", 0.9, (roadBottom + median) / 2, reverse: true)
        car("car_coral", 8.9, (roadTop + median) / 2, reverse: false)
        walk(roadTop: roadTop, roadBottom: roadBottom, fountain: fountain)
        if scene == .cityNight { night(roadTop: roadTop) }
        if scene == .campusRain { rain() }
    }

    private func car(_ name: String, _ start: CGFloat, _ y: CGFloat, reverse: Bool) {
        let pass = (time - start) / 2.7
        guard (0...1).contains(pass) else { return }
        let x = reverse ? 414 - pass * 468 : -54 + pass * 468
        if reverse {
            context.saveGState()
            context.translateBy(x: x * 2, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        sprite(name, x - 24, y - 18, 48, 36)
        if reverse { context.restoreGState() }
    }

    private func walk(roadTop: CGFloat, roadBottom: CGFloat, fountain: CGFloat) {
        func clamp(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
        for (index, walker) in Self.walkers.enumerated() {
            let clock = (time - walker.delay + 12).truncatingRemainder(dividingBy: 12)
            let approach = clamp(clock / 2)
            let crossing = clamp((clock - 3.5) / 3.1)
            let arrival = clamp((clock - 6.6) / 2)
            let beyondRoad = index == 1 ? roadTop - fountain - 8 : 24
            let foot = roadBottom + 52 - approach * 39 - crossing * (roadBottom - roadTop + 18) - arrival * (beyondRoad - 5)
            let x = Self.crossings[index] + (1 - approach) * walker.approach
            let alpha = max(0, min(clock / 0.5, (9.4 - clock) / 0.65, 1))
            guard alpha > 0 else { continue }
            let walking = clock < 2 || (3.5...8.6).contains(clock)
            let name = walking ? "\(walker.name)_w\(Int(clock * 8) % 3)" : walker.name
            if let art = Self.sprites[name] {
                bitmap(art, CGRect(x: (x - 12).rounded(), y: (foot - 28).rounded(), width: 24, height: 28), alpha: alpha)
            }
        }
    }

    private func night(roadTop: CGFloat) {
        paint(0, 0, width, height, 0x111534, alpha: 0.64)
        let warmth = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [rgb(0xFFD997, alpha: 0.48), rgb(0xFFD997, alpha: 0)] as CFArray,
                                locations: [0, 1])
        for lamp in [CGFloat(40), 180, 320] {
            let p = CGPoint(x: lamp, y: roadTop - 12)
            if let warmth {
                context.drawRadialGradient(warmth, startCenter: p, startRadius: 0, endCenter: p, endRadius: 64, options: [])
            }
            paint(lamp - 1, p.y, 2, 23, 0x1A1626)
            paint(lamp - 4, p.y - 2, 8, 4, 0xFFE07A)
        }
    }

    private func rain() {
        paint(0, 0, width, height, 0x253654, alpha: 0.26)
        let rows = Int(height / 46) + 2
        context.setStrokeColor(rgb(0xBCE4FF, alpha: 0.64))
        context.setLineWidth(1.25)
        context.setLineCap(.round)
        context.beginPath()
        for row in 0..<rows {
            for column in 0...11 {
                let y = (CGFloat(row) * height / CGFloat(rows) + time * height / 3).truncatingRemainder(dividingBy: height)
                let x = (CGFloat(column * 31 + row % 3 * 10) - y * 0.16 + width).truncatingRemainder(dividingBy: width)
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x - 4, y: y + 13))
            }
        }
        context.strokePath()
    }
}

private struct CreditsHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CampaignCreditsScreen: View {
    let onHome: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    @State private var creditsHeight: CGFloat = 0
    @State private var reviewOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MenuStreetAnimation(cycleScenes: true)
                    .accessibilityHidden(true)
                LinearGradient(stops: [
                    .init(color: MenuColors.shadow.opacity(0.85), location: 0),
                    .init(color: MenuColors.shadow.opacity(0.54), location: 0.5),
                    .init(color: MenuColors.shadow.opacity(0.90), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                if reduceMotion {
                    ScrollView {
                        credits(viewport: geometry.size.height)
                    }
                } else {
                    rollingCredits(viewport: geometry.size)
                }
            }
            .background(MenuColors.shadow)
            .clipped()
        }
    }

    private func rollingCredits(viewport: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tick in
            let end = max(0, creditsHeight - viewport.height)
            let elapsed = max(0, tick.date.timeIntervalSince(started) - 1.5)
            let travel = min(end, CGFloat(elapsed) * 42)
            let finished = creditsHeight > 0 && travel >= end
            let position = min(end, max(0, travel + reviewOffset + dragOffset))
            credits(viewport: viewport.height)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { measured in
                        Color.clear.preference(key: CreditsHeight.self, value: measured.size.height)
                    }
                }
                .offset(y: -position)
                .frame(width: viewport.width, height: viewport.height, alignment: .top)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture().updating($dragOffset) { input, delta, _ in
                        if finished { delta = -input.translation.height }
                    }.onEnded { input in
                        if finished {
                            reviewOffset = min(0, max(-end, reviewOffset - input.translation.height))
                        }
                    }
                )
        }
        .onPreferenceChange(CreditsHeight.self) { creditsHeight = $0 }
    }

    private func credits(viewport: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("¡Lo lograste!")
                    .font(.custom("Jersey10-Regular", size: 32))
                    .foregroundStyle(MenuColors.taxiLight)
                    .accessibilityAddTraits(.isHeader)
                creditText("Completaste los 12 niveles de Crosswalker.")
                Text("En colaboración con")
                    .font(.custom("PixelifySans-Regular", size: 14))
                    .foregroundStyle(MenuColors.creamLight)
                Image("fundacion_ado")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160 * 190 / 354)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background { MenuPanel(face: MenuColors.creamLight, corner: 6, shadow: true) }
                    .accessibilityLabel("Fundación ADO")
            }
            .frame(maxWidth: .infinity, minHeight: viewport * 0.86)

            VStack(spacing: 36) {
                section("Desarrollo") {
                    creditText("Juan Pablo Carrera Martinez")
                    creditText("Arturo Gutierez Lopez")
                    creditText("Diego Alberto Antonio Espinosa")
                    creditText("Shalom Israel Antonio Santiago")
                }
                section("Creación y dirección creativa") {
                    creditText("Juan Pablo Carrera Martinez")
                }
                section("Arte y tipografías") {
                    creditText("RPG Urban, Tiny City y Roguelike Modern City · Kenney · CC0")
                    creditLink("kenney.nl", "https://www.kenney.nl")
                    creditText("Silla de ruedas adaptada de [LPC Revised] Elders! · Eliza Wyatt, Stephen Challener, Durrani y BenCreating · OGA-BY 3.0")
                    creditLink("Proyecto LPC", "https://github.com/ElizaWy/LPC")
                    creditText("Jersey 10 y Jersey 25 · The Soft Type Project Authors")
                    creditText("Pixelify Sans · The Pixelify Sans Project Authors")
                    creditText("Silkscreen · The Silkscreen Project Authors")
                    creditText("Tipografías bajo SIL Open Font License 1.1")
                }
                section("Música y sonido") {
                    creditText("Jump and Run – Tropical Mix · bart · CC BY 3.0")
                    creditLink("OpenGameArt.org", "https://opengameart.org/content/jump-and-run-tropical-mix")
                    creditText("Market on the Sea · Compuesta por Jonathan Shaw")
                    creditLink("www.jshaw.co.uk", "https://www.jshaw.co.uk")
                    creditText("Talking Cute Chiptune · Alex McCulloch")
                    creditText("RPG Town Ambience 1 · HitCtrl")
                    creditText("Talking Synthesizer · tcarisland · CC BY 4.0")
                    creditLink("Talking Synthesizer en OpenGameArt", "https://opengameart.org/content/talking-synthesizer")
                }
            }
            .frame(maxWidth: 520)
            .padding(.vertical, 24)

            MenuActionButton(title: "VOLVER AL MENÚ DE INICIO", primary: true, action: onHome)
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity, minHeight: viewport * 0.72)
        }
        .padding(.horizontal, 24)
        .multilineTextAlignment(.center)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.custom("Jersey10-Regular", size: 24))
                .foregroundStyle(MenuColors.taxiLight)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func creditText(_ text: String) -> some View {
        Text(text)
            .font(.custom("PixelifySans-Regular", size: 18))
            .foregroundStyle(MenuColors.creamLight)
    }

    @ViewBuilder private func creditLink(_ label: String, _ destination: String) -> some View {
        if let url = URL(string: destination) {
            Link(destination: url) {
                Text(label)
                    .underline()
                    .font(.custom("PixelifySans-Regular", size: 18))
                    .foregroundStyle(MenuColors.skyLight)
            }
        }
    }
}
