import SwiftUI
import UIKit

struct Board: UIViewRepresentable {
    @ObservedObject var session: Session

    func makeUIView(context: Context) -> BoardCanvas { BoardCanvas(frame: .zero) }

    func updateUIView(_ view: BoardCanvas, context: Context) {
        view.update(level: session.level, plan: session.plan, simulation: session.simulation,
                    selected: session.selected, frame: session.frame)
        view.onCrossing = { session.crossing($0); session.beep() }
    }

    static func dismantleUIView(_ view: BoardCanvas, coordinator: ()) {
        view.stopAnimation()
    }
}

final class BoardCanvas: UIView {
    var onCrossing: (Int) -> Void = { _ in }
    private var level: Level?
    private var plan = Plan()
    private var simulation: Simulation?
    private var selected = ""
    private var frame = 0
    private var scenery: BoardScenery?
    private var observedPhase: Phase?
    private var impactStart: CFTimeInterval?
    private var animation: Timer?
    private var start = CACurrentMediaTime()
    private let art = BoardArt()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = true
        contentMode = .redraw
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }

    func update(level: Level, plan: Plan, simulation: Simulation?, selected: String, frame: Int) {
        let switchedLevel = self.level?.id != level.id
        if switchedLevel {
            scenery = makeBoardScenery(level)
            start = CACurrentMediaTime()
        }
        if switchedLevel || self.simulation !== simulation || observedPhase != simulation?.phase {
            observedPhase = simulation?.phase
            impactStart = (observedPhase == .retry || observedPhase == .won) ? CACurrentMediaTime() : nil
        }
        self.level = level
        self.plan = plan
        self.simulation = simulation
        self.selected = selected
        self.frame = frame
        accessibilityLabel = "\(level.title). Nivel \(level.id), mundo \(level.world + 1). Usa los botones de cruce para elegir izquierda, centro o derecha."
        refreshClock()
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshClock()
    }

    private var needsClock: Bool {
        guard window != nil, let level else { return false }
        if let impactStart, CACurrentMediaTime() - impactStart < 0.52 { return true }
        if level.weather == "rain" { return true }
        return (simulation == nil || simulation?.phase == .running) && level.walkers.contains {
            $0.kind == "headphones" && plan.people[$0.id]?.skills.contains("headphones_off") != true
        }
    }

    private func refreshClock() {
        if needsClock, animation == nil {
            let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.setNeedsDisplay()
                    if !self.needsClock { self.stopAnimation() }
                }
            }
            animation = timer
            RunLoop.main.add(timer, forMode: .common)
        } else if !needsClock {
            stopAnimation()
        }
    }

    func stopAnimation() {
        animation?.invalidate()
        animation = nil
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard simulation == nil, bounds.width > 0 else { return }
        let x = gesture.location(in: self).x / bounds.width
        onCrossing(x < 0.375 ? 0 : x < 0.625 ? 1 : 2)
    }

    override func draw(_ rect: CGRect) {
        guard let level, let scenery, let context = UIGraphicsGetCurrentContext(),
              bounds.width > 0, bounds.height > 0 else { return }
        let now = CACurrentMediaTime()
        let impact = impactStart.map { CGFloat(min(1, max(0, (now - $0) / 0.48))) } ?? 1
        context.saveGState()
        defer { context.restoreGState() }
        context.scaleBy(x: bounds.width / 360, y: bounds.height / 460)
        context.clip(to: CGRect(x: 0, y: 0, width: 360, height: 460))
        context.interpolationQuality = .none
        let painter = BoardPainter(context: context, art: art, level: level, plan: plan, simulation: simulation,
                                   scenery: scenery, selected: selected, frame: CGFloat(frame),
                                   elapsed: CGFloat(now - start), impact: impact,
                                   ratio: (bounds.width / 360) / (bounds.height / 460))
        painter.draw()
    }
}

@MainActor
private final class BoardArt {
    private var images: [String: UIImage] = [:]
    private var floors: [String: UIImage] = [:]

    func image(_ id: String) -> UIImage? {
        if let cached = images[id] { return cached }
        let value = UIImage(named: id) ?? Bundle.main.url(forResource: id, withExtension: "png")
            .flatMap { UIImage(contentsOfFile: $0.path) }
        images[id] = value
        return value
    }

    func floor(_ name: String) -> UIImage? {
        if let floor = floors[name] { return floor }
        guard let tile = image("ground_" + name) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let dimension = CGSize(width: 368, height: 464)
        let floor = UIGraphicsImageRenderer(size: dimension, format: format).image { drawing in
            drawing.cgContext.interpolationQuality = .none
            for y in stride(from: 0, to: 464, by: 16) {
                for x in stride(from: 0, to: 368, by: 16) {
                    tile.draw(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: 16, height: 16))
                }
            }
        }
        floors[name] = floor
        return floor
    }
}

private struct BoardPixel {
    let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
    let color: UInt32
}

private struct BoardProp {
    let id: String
    let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
}

private struct BoardSign {
    let text: String
    let x: CGFloat, y: CGFloat, width: CGFloat
}

private struct BoardScenery {
    let pixels: [BoardPixel]
    let props: [BoardProp]
    let lights: [BoardPixel]
    let signs: [BoardSign]
    let greenStrips: [(CGFloat, CGFloat)]
}

private func makeBoardScenery(_ level: Level) -> BoardScenery {
    var pixels: [BoardPixel] = []
    var props: [BoardProp] = []
    var lights: [BoardPixel] = []
    var signs: [BoardSign] = []
    let mirrored = level.id % 2 == 0
    let variant = (level.id - 1) % 4
    let roadCenters = level.lanes.map { CGFloat($0.y) * 410 }.sorted()
    let greenStrips = Array(zip([72] + roadCenters.map { $0 + 36 }, roadCenters.map { $0 - 32 } + [335]))

    func xPosition(_ x: Int, _ width: Int) -> CGFloat { CGFloat(mirrored ? 360 - x - width : x) }

    func pixel(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: UInt32) {
        pixels.append(BoardPixel(x: xPosition(x, width), y: CGFloat(y), width: CGFloat(width),
                                 height: CGFloat(height), color: color))
    }

    func prop(_ id: String, _ x: Int, _ y: Int, _ width: Int, _ height: Int) {
        props.append(BoardProp(id: id, x: xPosition(x, width), y: CGFloat(y), width: CGFloat(width),
                               height: CGFloat(height)))
    }

    func planter(_ x: Int, _ y: Int, _ width: Int, _ bloom: UInt32) {
        pixel(x + 2, y + 8, width, 5, 0x227E78)
        pixel(x, y, width, 10, 0x76536B)
        pixel(x + 1, y + 6, width - 2, 3, 0xA97B7E)
        pixel(x + 2, y + 1, width - 4, 5, 0x245F55)
        for leaf in stride(from: 3, to: width - 3, by: 5) {
            pixel(x + leaf, y + 2, 3, 3, 0x50AD7B)
            pixel(x + leaf + 1, y, 2, 2, bloom)
        }
    }
    func flowerBed(_ x: Int, _ y: Int, _ bloom: UInt32, _ accent: UInt32) {
        pixel(x + 2, y + 7, 34, 7, 0x2C655D)
        pixel(x, y + 1, 36, 10, 0x527E68)
        pixel(x + 2, y + 2, 32, 7, 0x316A58)
        for flower in 0...4 {
            let left = x + 4 + flower * 6
            let top = y + flower % 2 * 3
            pixel(left + 2, top + 3, 1, 5, 0x8ABB7A)
            pixel(left, top + 1, 5, 2, flower % 2 == 0 ? bloom : accent)
            pixel(left + 1, top, 3, 4, flower % 2 == 0 ? bloom : accent)
            pixel(left + 2, top + 1, 1, 2, 0xFFE5A2)
        }
    }
    func puddle(_ x: Int, _ y: Int) {
        pixel(x + 4, y, 21, 10, 0x42677B)
        pixel(x, y + 3, 29, 4, 0x42677B)
        pixel(x + 5, y + 2, 17, 2, 0x719DB1)
        pixel(x + 8, y + 6, 8, 1, 0xADD7E2)
        pixel(x + 18, y + 5, 5, 1, 0x8EBAC9)
    }
    func mosaic(_ x: Int, _ y: Int, _ colors: [UInt32]) {
        pixel(x, y, 30, 14, 0x595671)
        pixel(x + 1, y + 1, 28, 12, 0xB0A4AA)
        for row in 0...2 {
            for column in 0...6 {
                let color = colors[(column + row + variant) % colors.count]
                pixel(x + 2 + column * 4, y + 2 + row * 4, 3, 3, color)
            }
        }
    }
    func bench(_ x: Int, _ y: Int) {
        pixel(x + 2, y + 8, 24, 3, 0x227E78)
        pixel(x + 2, y, 2, 10, 0x4E4A63)
        pixel(x + 22, y, 2, 10, 0x4E4A63)
        pixel(x, y, 26, 3, 0xB67857)
        pixel(x, y + 5, 26, 3, 0xE0A476)
    }
    func paving(_ x: Int, _ y: Int, _ width: Int, _ height: Int) {
        pixel(x, y, width, height, 0x77748C)
        pixel(x + 1, y + 1, width - 2, height - 2, 0x9D9AB0)
        for joint in stride(from: 4, to: height, by: 6) {
            pixel(x + 1, y + joint, width - 2, 1, 0x827E98)
        }
    }

    func sign(_ text: String, _ x: Int, _ y: Int, _ width: Int) {
        signs.append(BoardSign(text: text, x: xPosition(x, width), y: CGFloat(y), width: CGFloat(width)))
    }

    func facade(_ x: Int, _ width: Int, _ wall: UInt32, _ roof: UInt32, _ title: String, windowsLit: Bool = false) {
        pixel(x + 4, 12, width, 40, 0x5A556A)
        pixel(x, 10, width, 38, 0x40394F)
        pixel(x + 2, 12, width - 4, 34, wall)
        pixel(x - 2, 5, width + 4, 9, roof)
        pixel(x + 2, 5, width - 4, 2, 0xE0A476)
        pixel(x + 3, 43, width - 6, 3, roof)
        let door = x + width / 2 - 7
        pixel(door, 30, 14, 18, 0x40394F)
        pixel(door + 2, 32, 10, 14, 0x769EB1)
        pixel(door + 7, 32, 1, 14, 0x40394F)
        pixel(door - 2, 48, 18, 2, 0xC5B7A2)
        for window in [x + 8, x + width - 22] {
            pixel(window, 25, 14, 13, 0x40394F)
            pixel(window + 2, 27, 10, 9, windowsLit ? 0xE4AA68 : 0x9BC5D1)
            pixel(window + 6, 27, 2, 9, 0x655B72)
            pixel(window + 1, 38, 12, 2, 0xD9B295)
            if windowsLit {
                lights.append(BoardPixel(x: xPosition(window + 2, 4), y: 27, width: 4, height: 6, color: 0xFFE0A0))
                lights.append(BoardPixel(x: xPosition(window + 8, 4), y: 27, width: 4, height: 6, color: 0xFFE0A0))
            }
        }
        let signWidth = title.count > 7 ? 66 : 54
        if !title.isEmpty { sign(title, x + (width - signWidth) / 2, 15, signWidth) }
    }

    func schoolBus(_ x: Int, _ y: Int) {
        pixel(x + 1, y + 24, 78, 3, 0x444052)
        pixel(x + 2, y + 3, 75, 21, 0x2B2540)
        pixel(x + 5, y, 62, 5, 0x2B2540)
        pixel(x + 7, y + 2, 57, 4, 0xFFE07A)
        pixel(x + 4, y + 6, 71, 16, 0xFFC23D)
        pixel(x + 4, y + 19, 71, 3, 0xD98A1C)
        pixel(x + 67, y + 5, 8, 10, 0x4E4A63)
        pixel(x + 69, y + 6, 4, 7, 0xB9DAEC)
        for window in stride(from: 9, through: 54, by: 11) {
            pixel(x + window, y + 6, 8, 8, 0x4E4A63)
            pixel(x + window + 1, y + 7, 6, 2, 0xB9DAEC)
        }
        pixel(x + 5, y + 16, 69, 2, 0x4E4A63)
        pixel(x + 61, y + 8, 1, 14, 0x9B6529)
        for wheel in [12, 60] {
            pixel(x + wheel, y + 20, 10, 8, 0x2B2540)
            pixel(x + wheel + 3, y + 23, 4, 3, 0x9C99B5)
        }
        pixel(x + 73, y + 18, 4, 3, 0xFFF8E6)
        pixel(x + 2, y + 17, 3, 3, 0xD9483F)
    }

    func playCourt(_ x: Int, _ y: Int) {
        let line: UInt32 = 0xE8E3CF
        let surface: UInt32 = variant == 3 ? 0x9D665D : 0x36796F
        pixel(x, y, 92, 44, 0x514E69)
        pixel(x + 2, y + 2, 88, 40, surface)
        pixel(x + 7, y + 6, 78, 1, line)
        pixel(x + 7, y + 36, 78, 1, line)
        pixel(x + 7, y + 7, 1, 29, line)
        pixel(x + 84, y + 7, 1, 29, line)
        pixel(x + 45, y + 7, 1, 29, line)
        pixel(x + 41, y + 17, 9, 9, line)
        pixel(x + 43, y + 19, 5, 5, surface)
        for goal in [3, 83] {
            pixel(x + goal, y + 15, 6, 13, line)
            pixel(x + goal + 1, y + 16, 4, 11, 0x879DAC)
            for net in stride(from: 18, through: 25, by: 3) { pixel(x + goal + 1, y + net, 4, 1, line) }
        }
        pixel(x + 54, y + 28, 4, 4, 0x2B2540)
        pixel(x + 55, y + 28, 2, 2, 0xFFF8E6)
    }

    func hopscotch(_ x: Int, _ y: Int) {
        for row in 0...4 {
            let paired = row == 1 || row == 3
            let offset = paired ? 0 : 4
            let width = paired ? 16 : 8
            pixel(x + offset, y + row * 5, width, 5, 0xFFF8E6)
            pixel(x + offset + 1, y + row * 5 + 1, width - 2, 3, 0x6B90AD)
            if paired { pixel(x + 7, y + row * 5 + 1, 2, 3, 0xFFF8E6) }
        }
    }

    func busShelter(_ x: Int, _ y: Int) {
        pixel(x, y + 24, 48, 5, 0x67637E)
        pixel(x + 3, y + 5, 38, 17, 0x73909F)
        pixel(x + 7, y + 7, 29, 2, 0xB9DAEC)
        pixel(x + 10, y + 15, 25, 4, 0xC58C68)
        pixel(x + 3, y + 4, 3, 22, 0x40394F)
        pixel(x + 38, y + 4, 3, 22, 0x40394F)
        pixel(x, y, 44, 6, 0x40394F)
        pixel(x + 2, y + 1, 40, 2, 0xA6ABC5)
        pixel(x + 47, y + 2, 2, 24, 0x40394F)
        pixel(x + 44, y + 2, 8, 7, 0x7CC6F5)
        pixel(x + 46, y + 4, 4, 3, 0x2B2540)
    }

    switch level.world {
    case 1:
        paving(5, 4, 350, 52)
        playCourt(12, 6)
        hopscotch(109, 23)
        facade(132, 96, 0xDCA783, 0x596C90, "ESCUELA")
        pixel(246, 10, 101, 42, 0x67637E)
        pixel(248, 12, 97, 38, 0x514E69)
        for edge in [252, 340] { pixel(edge, 15, 2, 31, 0xD3C9B2) }
        schoolBus(256, 15 + variant)
        prop("tree_autumn", 5, 354, 32, 49)
        bench(9, 416)
        paving(322, 378, 34, 61)
        if variant == 1 || variant == 3 { hopscotch(330, 403) }
        else { prop("decor_bikerack_campus", 324, 379, 28, 24) }
        planter(323, 431, 27, 0xFFE07A)
        mosaic(11, 435, [0x6C92AD, 0xECD69A, 0xB7777E])
    case 2:
        paving(5, 35, 350, 21)
        let titles = [("CAFÉ", "PAN"), ("TIENDA", "TALLER"), ("LIBROS", "CAFÉ"), ("MERCADO", "PAN")]
        let (first, second) = titles[variant]
        facade(13, 105, 0x996A77, 0x56546F, first, windowsLit: true)
        facade(237, 110, 0x798399, 0x514D70, second, windowsLit: true)
        busShelter(155, 22)
        paving(4, 361, 42, 73)
        prop("tree_autumn", 9, 359, 30, 40)
        bench(10, 407)
        paving(316, 390, 40, 49)
        planter(322, 418, 29, 0x7CC6F5)
        mosaic(11, 440, [0x9C6C94, 0x7CA9AB, 0xE0AB82])
    default:
        let walls: [UInt32] = [0xD7A98B, 0xC28A83, 0xADB58A, 0xD5A171]
        paving(42, 44, 30, 12)
        paving(269, 44, 30, 12)
        facade(15, 84, walls[variant], 0x95605B, "")
        facade(241, 86, walls[(variant + 2) % 4], 0x62778B, "")
        prop("decor_fence_barrio", 104, 23, 44, 24)
        prop("tree", 153, 1, 34, 47)
        prop("tree_autumn", 201, 4, 29, 41)
        prop("decor_mailbox_barrio", 99, 29, 25, 24)
        planter(137, 42, 28, 0xF27A6B)
        planter(198, 42, 31, 0xFFE07A)
        prop("tree", 5, 354, 32, 55)
        bench(10, 418)
        prop("decor_fence_barrio", 317, 369, 39, 26)
        planter(320, 408, 32, 0xF27A6B)
        planter(323, 434, 25, 0xFFE07A)
        flowerBed(6, 437, 0xECA7BA, 0xFFDB91)
    }

    for (top, bottom) in greenStrips {
        guard bottom - top >= 22 else { continue }
        let y = Int((top + bottom) / 2 - 7)
        // These props stay at the outside edges, away from every possible crossing.
        switch level.world {
        case 1:
            flowerBed(8, y, 0xFFE19A, 0xF0AA94)
            if level.weather == "rain" { puddle(321, y + 2) }
            else { mosaic(322, y, [0x709CBC, 0xD6AF75, 0x82AD96]) }
        case 2:
            flowerBed(8, y, 0x9AC5E4, 0xC7A3E0)
            if level.weather == "rain" { puddle(321, y + 2) }
            else { flowerBed(317, y, 0xC7A3E0, 0x88C3BB) }
        default:
            flowerBed(8, y, 0xF2A5AC, 0xF8CA7B)
            flowerBed(317, y, 0xD7B4E0, 0xFFD898)
        }
    }
    if level.weather == "rain" { puddle(13, 343) }
    return BoardScenery(pixels: pixels, props: props, lights: lights, signs: signs, greenStrips: greenStrips)
}

@MainActor
private final class BoardPainter {
    let c: CGContext
    let art: BoardArt
    let level: Level
    let plan: Plan
    let simulation: Simulation?
    let scenery: BoardScenery
    let selected: String
    let frame: CGFloat
    let elapsed: CGFloat
    let impact: CGFloat
    let ratio: CGFloat
    private let board = CGRect(x: 0, y: 0, width: 360, height: 460)
    private let asphalt: UInt32 = 0x5C6278
    private let marking: UInt32 = 0xA09CCA
    private let ink: UInt32 = 0x2B2540
    private let worldText: UInt32 = 0xFFF8E6
    private var lights: [(x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat)] = []
    private var schoolSigns: [CGPoint] = []
    private var impactedCar: LocatedArt?

    private struct LocatedArt {
        let id: String
        let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        let flipped: Bool
    }

    init(context: CGContext, art: BoardArt, level: Level, plan: Plan, simulation: Simulation?,
         scenery: BoardScenery, selected: String, frame: CGFloat, elapsed: CGFloat, impact: CGFloat,
         ratio: CGFloat) {
        c = context
        self.art = art
        self.level = level
        self.plan = plan
        self.simulation = simulation
        self.scenery = scenery
        self.selected = selected
        self.frame = frame
        self.elapsed = elapsed
        self.impact = impact
        self.ratio = ratio
    }

    func draw() {
        ground(0, 0, 360, 460, "grass")
        drawScenery(near: false)
        for sign in scenery.signs {
            rect(sign.x, sign.y, sign.width, 10, ink)
            rect(sign.x + 1, sign.y + 1, sign.width - 2, 8, 0xFFE0A0)
            label(sign.text, sign.x + sign.width / 2, sign.y + 8, 9, worldText)
        }
        ground(0, 56, 360, 16, "walk")
        rect(0, 56, 360, 2, asphalt)
        rect(0, 70, 360, 1, 0x6D7186)
        for x in stride(from: 16, through: 352, by: 24) { rect(CGFloat(x), 59, 1, 10, 0x8B879F) }

        drawConnectingPaths()
        let preview = simulation ?? Simulation(level, plan)
        for (index, lane) in level.lanes.enumerated() { drawLane(lane, first: index == 0, preview: preview) }
        drawPavement()
        if simulation == nil { drawCrossingChoices() }
        for walker in level.walkers { drawWalker(walker, preview: preview) }
        if let simulation { drawResult(simulation) }
        if level.night { drawNight() }
        for position in schoolSigns { schoolBadge(at: position) }
    }

    private func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                      _ hex: UInt32, _ alpha: CGFloat = 1) {
        c.setFillColor(color(hex, alpha).cgColor)
        c.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private func line(_ x: CGFloat, _ y: CGFloat, _ x2: CGFloat, _ y2: CGFloat,
                      _ hex: UInt32, width: CGFloat = 1, alpha: CGFloat = 1, dash: [CGFloat] = []) {
        c.setStrokeColor(color(hex, alpha).cgColor)
        c.setLineWidth(width)
        c.setLineDash(phase: 0, lengths: dash)
        c.beginPath()
        c.move(to: CGPoint(x: x, y: y))
        c.addLine(to: CGPoint(x: x2, y: y2))
        c.strokePath()
    }

    private func polygon(_ points: [CGPoint], _ hex: UInt32) {
        guard let first = points.first else { return }
        c.beginPath()
        c.move(to: first)
        for point in points.dropFirst() { c.addLine(to: point) }
        c.closePath()
        c.setFillColor(color(hex).cgColor)
        c.fillPath()
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                         _ hex: UInt32, _ alpha: CGFloat = 1) {
        c.setFillColor(color(hex, alpha).cgColor)
        c.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
    }

    private func spriteBounds(_ image: UIImage, _ x: CGFloat, _ y: CGFloat,
                              _ w: CGFloat, _ h: CGFloat) -> CGRect {
        let aspect = image.size.width / image.size.height
        let height = min(h, w * ratio / aspect)
        let width = height * aspect / ratio
        let left = x + (w - width) / 2
        let top = y + h - height
        // Match the integer sprite bounds used by the board's pixel renderer.
        let px = left.rounded(.towardZero), py = top.rounded(.towardZero)
        return CGRect(x: px, y: py, width: (left + width).rounded(.towardZero) - px,
                      height: (y + h).rounded(.towardZero) - py)
    }

    @discardableResult
    private func sprite(_ id: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat,
                        _ h: CGFloat, flipped: Bool = false) -> CGRect? {
        guard let image = art.image(id) else { return nil }
        let bounds = spriteBounds(image, x, y, w, h)
        c.saveGState()
        if flipped {
            c.translateBy(x: 2 * x + w, y: 0)
            c.scaleBy(x: -1, y: 1)
        }
        image.draw(in: bounds)
        c.restoreGState()
        return bounds
    }

    private func label(_ text: String, _ x: CGFloat, _ baseline: CGFloat,
                       _ size: CGFloat, _ hex: UInt32, outlined: Bool = true) {
        let font = UIFont(name: "PixelifySans-Bold", size: size)
            ?? UIFont(name: "PixelifySans-Regular", size: size)
            ?? .boldSystemFont(ofSize: size)
        let value = text as NSString
        let position = CGPoint(x: x - value.size(withAttributes: [.font: font]).width / 2,
                               y: baseline - font.ascender)
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color(hex)]
        if outlined {
            attributes[.strokeColor] = color(hex == ink ? worldText : ink)
            attributes[.strokeWidth] = -200 / size
        }
        value.draw(at: position, withAttributes: attributes)
    }

    private func ground(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ type: String) {
        guard let floor = art.floor(type) else { return }
        c.saveGState()
        c.clip(to: CGRect(x: x, y: y, width: w, height: h))
        floor.draw(at: .zero)
        c.restoreGState()
    }

    private func drawScenery(near: Bool) {
        for p in scenery.pixels where (p.y >= 335) == near {
            rect(p.x, p.y, p.width, p.height, p.color)
        }
        for prop in scenery.props where (prop.y >= 335) == near {
            sprite(prop.id, prop.x, prop.y, prop.width, prop.height)
        }
    }

    private func drawConnectingPaths() {
        let crossings = Simulation.crossings.enumerated().filter { index, _ in
            if level.night && !level.pedestrianCrossings.isEmpty { return level.hasMarkedCrossing(index) }
            return index != level.blockedCrossing
        }
        for (top, bottom) in scenery.greenStrips where bottom - top >= 9 {
            for (_, crossing) in crossings {
                let left = CGFloat(crossing) * 360 - 13
                rect(left - 2, top, 30, bottom - top, 0x318981)
                ground(left, top, 26, bottom - top, "walk")
            }
        }
    }

    private func zebra(_ x: CGFloat, _ y: CGFloat) {
        let left = x - 19
        ground(left, y - 30, 38, 64, "road")
        for stripe in 0..<6 {
            let top = y - 26 + CGFloat(stripe) * 10
            rect(left, top, 38, 6, worldText)
            rect(left, top + 5, 38, 1, 0xD6D7E0)
        }
    }

    private func headlights(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, direction: CGFloat) {
        guard level.night, plan.street.contains("car_lights") else { return }
        let center = x + direction * (width / 2 + 45)
        let separation = height * 0.15
        lights.append((center, y - separation, 48, 28))
        lights.append((center, y + separation, 48, 28))
    }

    private func slowMotion(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        guard !level.tutorial, simulation?.phase == .running, plan.street.contains("speed_zone") else { return }
        let pulse = 0.82 + 0.18 * sin(frame * 0.12)
        ellipse(x - w * 0.72, y - h * 0.58, w * 1.44, h * 1.16, 0xA855F7, 145 * pulse / 255)
        let cx = x + w * 0.52 + 8, cy = y - h * 0.28
        ellipse(cx - 6, cy - 6, 12, 12, 0xF3E8FF)
        c.setStrokeColor(color(0x7E22CE).cgColor)
        c.setLineDash(phase: 0, lengths: [])
        c.setLineWidth(1.6)
        c.strokeEllipse(in: CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12))
        let theta = frame * 0.16
        line(cx, cy, cx + 3 * sin(theta), cy - 3 * cos(theta), 0x7E22CE)
        line(cx, cy, cx - 2 * sin(theta * 0.55), cy + 2 * cos(theta * 0.55), 0x7E22CE)
    }

    private func drawLane(_ lane: Lane, first: Bool, preview: Simulation) {
        let y = CGFloat(lane.y) * 410
        ground(0, y - 32, 360, 68, "road")
        rect(0, y - 32, 360, 2, marking)
        rect(0, y + 34, 360, 2, marking)
        for i in 0...11 { rect(CGFloat(i) * 32 + 6, y, 18, 2, marking) }

        if level.night && !level.pedestrianCrossings.isEmpty {
            for (i, x) in Simulation.crossings.enumerated() where level.hasMarkedCrossing(i) {
                zebra(CGFloat(x) * 360, y)
            }
        } else if plan.street.contains("crosswalk") {
            for (i, x) in Simulation.crossings.enumerated() where level.tutorial || level.accessible.contains(i) {
                zebra(CGFloat(x) * 360, y)
            }
        } else if first { zebra(180, y) }

        let width: CGFloat = lane.blindSpot ? 64 : 52
        let height: CGFloat = lane.blindSpot ? 44 : 38
        let x = CGFloat(preview.carX(lane)) * 360
        let carY = lane.twoWay ? y - 16 : y
        let direction: CGFloat = lane.speed < 0 ? -1 : 1

        @discardableResult
        func car(_ x: CGFloat, _ y: CGFloat, _ direction: CGFloat) -> LocatedArt {
            headlights(x: x, y: y, width: width, height: height, direction: direction)
            slowMotion(x, y, width, height)
            let placement = LocatedArt(id: lane.car, x: x - width / 2, y: y - height / 2,
                                       width: width, height: height, flipped: direction < 0)
            sprite(placement.id, placement.x, placement.y, width, height, flipped: placement.flipped)
            return placement
        }

        let main = car(x, carY, direction)
        if !level.tutorial, simulation?.isBraking(lane) == true {
            let tailX = x - direction * (width / 2 - 4)
            ellipse(tailX - 4, carY - 4, 8, 8, 0xF27A6B)
        }
        let opposite = lane.twoWay ? car(CGFloat(preview.oncomingCarX(lane)) * 360, y + 17, -direction) : nil
        let ambushY = lane.twoWay ? y + 17 : carY
        let ambushes = preview.ambushCarsFor(lane).map { position in
            (position.x, car(CGFloat(position.x) * 360, ambushY, CGFloat(position.direction)))
        }
        if let simulation, simulation.phase == .retry, lane == simulation.collapsedLane {
            switch simulation.collapsedCarRole {
            case .main?: impactedCar = main
            case .oncoming?: impactedCar = opposite
            case .ambush?:
                if let hitX = simulation.collapsedCarX {
                    impactedCar = ambushes.min { abs($0.0 - hitX) < abs($1.0 - hitX) }?.1
                }
            case nil: break
            }
        }
        if !level.tutorial, let simulation {
            if simulation.carSpeed(lane) < 0.002 { label("ALTO", x, carY - 24, 11, 0xFFE07A) }
            else if simulation.isBraking(lane) { label("FRENA", x, carY - 24, 11, 0xF27A6B) }
        }
    }

    private func drawPavement() {
        ground(0, 335, 360, 125, "walk")
        rect(0, 335, 360, 2, asphalt)
        rect(0, 338, 360, 1, 0x817D95)
        drawScenery(near: true)

        if let blocked = level.blockedCrossing, Simulation.crossings.indices.contains(blocked) {
            let x = CGFloat(Simulation.crossings[blocked]) * 360
            sprite(level.world == 1 ? "obstacle_cone_campus" : "obstacle_barricade_barrio",
                   x - 20, 297, 40, 40)
            rect(x - 32, 336, 64, 13, 0xF5A94C)
            line(x - 27, 339, x - 21, 345, ink, width: 1.3)
            line(x - 21, 339, x - 27, 345, ink, width: 1.3)
            label("CERRADO: OBRA", x + 3, 345, 8, ink)
        }
        guard !level.tutorial else { return }
        if plan.street.contains("crosswalk") {
            for (index, crossing) in Simulation.crossings.enumerated() where level.accessible.contains(index) {
                let x = CGFloat(crossing) * 360
                sprite("ramp", x - 18, 311, 36, 30)
                label("RAMPA", x, 353, 10, worldText)
            }
        }
        if plan.street.contains("lighting") {
            lights.append((180, 210, 90, 90))
            label("LUZ", 180, 88, 11, 0xFFE07A)
        }
        let weather: String
        switch level.weather {
        case "rain": weather = "LLUVIA · FRENADO LARGO"
        case "fog": weather = "NIEBLA · VISTA REDUCIDA"
        default: weather = level.night ? "NOCHE" : "DÍA"
        }
        label(weather, 180, 455, 11, worldText)
        if level.weather == "rain" {
            rect(0, 0, 360, 330, 0x1B2440, 35 / 255)
            let fall = (Int(elapsed * 20) * 7) % 340
            c.setStrokeColor(color(0xCFE0ED, 160 / 255).cgColor)
            c.setLineWidth(0.75)
            c.setLineDash(phase: 0, lengths: [])
            c.beginPath()
            for i in 0...70 {
                let x = CGFloat(i * 37 % 370 - 5), y = CGFloat((i * 53 % 340 + fall) % 340)
                c.move(to: CGPoint(x: x, y: y))
                c.addLine(to: CGPoint(x: x - 5, y: y + 16))
            }
            c.strokePath()
        } else if level.weather == "fog" {
            rect(0, 56, 360, 274, 0xDDE2E9, 110 / 255)
        }
    }

    private func drawCrossingChoices() {
        for (index, crossing) in Simulation.crossings.enumerated() {
            let x = CGFloat(crossing) * 360
            let active = plan.people[selected]?.crossing == index
            let blocked = level.blockedCrossing == index
            let box = UIBezierPath(roundedRect: CGRect(x: x - 26, y: 349, width: 52, height: 65), cornerRadius: 4)
            let tint: UInt32 = blocked ? 0xF5A94C : active ? 0xFFFFFF : 0x8B8AB1
            if blocked {
                c.setFillColor(color(0xF5A94C, 70 / 255).cgColor)
                c.addPath(box.cgPath)
                c.fillPath()
            }
            c.setStrokeColor(color(tint).cgColor)
            c.setLineWidth(active || blocked ? 2.5 : 1)
            c.setLineDash(phase: 0, lengths: [5, 5])
            c.addPath(box.cgPath)
            c.strokePath()
            if active {
                line(x, 343, x, 72, tint, width: 2.5, dash: [5, 5])
                polygon([CGPoint(x: x, y: 69), CGPoint(x: x - 5, y: 79), CGPoint(x: x + 5, y: 79)], tint)
            }
            label(blocked ? "CERRADO" : ["IZQ.", "CENTRO", "DER."][index], x, 429, 11,
                  blocked ? 0xF5A94C : worldText)
            if level.night && !blocked && !level.pedestrianCrossings.isEmpty {
                let marked = level.hasMarkedCrossing(index)
                label(marked ? "PASO PEATONAL" : "SIN PASO", x, 442, 9, marked ? 0xFFE07A : 0xF5A94C)
            }
        }
    }

    private func bubble(_ x: CGFloat, _ y: CGFloat, glyph: String? = nil) {
        let left = x - 11, top = y - 17
        rect(left - 1, top - 1, 24, 19, ink)
        polygon([CGPoint(x: x - 5, y: y), CGPoint(x: x + 1, y: y + 5),
                 CGPoint(x: x + 3, y: y)], ink)
        rect(left, top, 22, 17, 0xF4EAD0)
        polygon([CGPoint(x: x - 4, y: y), CGPoint(x: x + 1, y: y + 3),
                 CGPoint(x: x + 2, y: y)], 0xF4EAD0)
        if let glyph { label(glyph, x, y - 4, 12, 0xD9483F, outlined: false) }
        else { sprite("phone", x - 4, top + 2, 8, 13) }
    }

    private func musicNotes(head: CGPoint) {
        let phase = (elapsed / 2.1).truncatingRemainder(dividingBy: 1)
        for index in 0..<3 {
            let age = (phase + CGFloat(index) / 3).truncatingRemainder(dividingBy: 1)
            let direction: CGFloat = index == 1 ? -1 : 1
            let x = head.x + direction * (4 + age * 14) + sin(age * 5) * 3
            let y = head.y - 3 - age * 40
            let opacity = max(0, min(age * 12, 1 - age))
            rect(x - 4, y + 1, 7, 6, ink, 245 / 255 * opacity)
            rect(x, y - 8, 4, 12, ink, 245 / 255 * opacity)
            rect(x + 3, y - 8, 5, 5, ink, 245 / 255 * opacity)
            let tint: UInt32 = index == 1 ? 0x7CC6F5 : 0xFFE07A
            rect(x - 3, y + 2, 5, 4, tint, opacity)
            rect(x + 1, y - 7, 2, 11, tint, opacity)
            rect(x + 3, y - 7, 4, 3, tint, opacity)
        }
    }

    private func backpack(in bounds: CGRect, fromBack: Bool) {
        c.saveGState()
        c.translateBy(x: bounds.minX, y: bounds.minY)
        c.scaleBy(x: bounds.width / 12, y: bounds.height / 14)
        if fromBack {
            rect(5, 8, 2, 1, ink)
            rect(3, 9, 6, 4, ink)
            rect(4, 9, 4, 3, 0xFFC23D)
            rect(4, 10.5, 4, 1.5, 0xFFE07A)
            rect(5.5, 11, 1, 1, ink)
        } else {
            rect(1.5, 8.5, 2, 4, ink)
            rect(8.5, 8.5, 2, 4, ink)
            rect(2, 8.5, 1, 3.5, 0xFFC23D)
            rect(9, 8.5, 1, 3.5, 0xFFC23D)
            rect(1, 10, 1, 2, 0xFFE07A)
            rect(10, 10, 1, 2, 0xFFE07A)
        }
        c.restoreGState()
    }

    private func schoolBadge(at position: CGPoint) {
        c.saveGState()
        c.translateBy(x: position.x, y: position.y)
        let shape = [CGPoint(x: 12, y: 0), CGPoint(x: 24, y: 12),
                     CGPoint(x: 12, y: 24), CGPoint(x: 0, y: 12)]
        polygon(shape, ink)
        polygon(shape.map { CGPoint(x: 12 + ($0.x - 12) * 0.83, y: 12 + ($0.y - 12) * 0.83) }, 0xFFE07A)
        let figures: [CGRect] = [
            CGRect(x: 8, y: 6, width: 3, height: 3), CGRect(x: 7, y: 9, width: 4, height: 5),
            CGRect(x: 6, y: 14, width: 2, height: 3), CGRect(x: 9, y: 14, width: 2, height: 4),
            CGRect(x: 14, y: 9, width: 3, height: 3), CGRect(x: 14, y: 12, width: 3, height: 4),
            CGRect(x: 13, y: 15, width: 2, height: 3), CGRect(x: 16, y: 15, width: 2, height: 2),
            CGRect(x: 11, y: 11, width: 2, height: 2), CGRect(x: 12, y: 12, width: 2, height: 2)
        ]
        c.setFillColor(color(ink).cgColor)
        c.fill(figures)
        c.restoreGState()
    }

    private func drawWalker(_ walker: Walker, preview: Simulation) {
        let person = simulation?.people.first { $0.walker.id == walker.id }
        let assignment = plan.people[walker.id] ?? Assignment()
        let crossing = Simulation.crossings.indices.contains(assignment.crossing) ? assignment.crossing : 1
        let x = CGFloat(person?.x ?? Simulation.crossings[crossing]) * 360
        let y = CGFloat(person?.y ?? 0.91) * 410
        if simulation == nil {
            let range = CGFloat(preview.sightRange(walkerId: walker.id)) * 360
            let laneY = CGFloat(level.lanes.map(\.y).max() ?? 0.5) * 410
            let short = range < 180
            rect(x - range, laneY - 10, range * 2, 20, short ? 0xF27A6B : 0xFFE07A, 55 / 255)
            if short { label("¡OJO!", x, laneY - 16, 11, 0xF27A6B) }
            if walker.id == selected { ellipse(x - 16, y - 7, 32, 12, 0xFFE07A) }
        }
        if level.night && assignment.skills.contains("visible") { lights.append((x, y - 19, 30, 30)) }

        let collapsed = simulation?.phase == .retry && simulation?.collapsedWalkerId == walker.id
        let walking = person != nil && !collapsed
        let spriteID = walking ? "\(walker.sprite)_w\(Int((person?.y ?? 0) * 32) % 3)" : walker.sprite
        if walker.kind == "headphones" && !assignment.skills.contains("headphones_off") {
            if let bounds = sprite(spriteID, x - 15, y - 38, 30, 42) {
                let top = bounds.minY + bounds.height * (walking ? 0.025 : 0.06)
                let left = bounds.minX + bounds.width * 0.06
                art.image("headphones")?.draw(in: CGRect(x: left, y: top, width: bounds.width * 0.88, height: bounds.height * 0.36))
                if !collapsed && person?.done != true && (simulation == nil || simulation?.phase == .running) {
                    musicNotes(head: CGPoint(x: bounds.midX, y: top))
                }
            }
        } else if level.showsChildBadge(walker) {
            let width: CGFloat = 30 * 0.84, height: CGFloat = 42 * 0.84
            if let bounds = sprite(spriteID, x - width / 2, y + 4 - height, width, height) {
                backpack(in: bounds, fromBack: walking)
            }
            if person?.done != true && (simulation == nil || simulation?.phase == .running) {
                schoolSigns.append(CGPoint(x: x - 12, y: max(4, y - height - 24)))
            }
        } else {
            sprite(spriteID, x - 15, y - 38, 30, 42)
        }
        if walker.kind == "phone" && !assignment.skills.contains("phone_away") {
            bubble(x, max(y - 60, 4) + 17)
        }
        if person?.done == true { bubble(x + 14, max(y - 40, 26), glyph: "♥") }
    }

    private func reveal(_ placement: LocatedArt, tint: UInt32, alpha: CGFloat, scale: CGFloat) {
        guard let image = art.image(placement.id) else { return }
        let fitted = spriteBounds(image, placement.x, placement.y, placement.width, placement.height)
        let enlarged = fitted.insetBy(dx: -(scale - 1) * fitted.width / 2,
                                      dy: -(scale - 1) * fitted.height / 2)
        c.saveGState()
        if placement.flipped {
            c.translateBy(x: 2 * placement.x + placement.width, y: 0)
            c.scaleBy(x: -1, y: 1)
        }
        image.withTintColor(color(tint), renderingMode: .alwaysOriginal).draw(in: enlarged, blendMode: .normal, alpha: alpha)
        image.draw(in: fitted, blendMode: .destinationOut, alpha: 1)
        c.restoreGState()
    }

    private func burst(_ x: CGFloat, _ y: CGFloat, eased: CGFloat, palette: [UInt32]) {
        guard eased < 1 else { return }
        let radius = 55 * eased
        let alpha = (1 - eased) * 220 / 255
        for i in 0..<8 {
            let angle = CGFloat(i) / 8 * 2 * .pi + 0.3
            rect(x + cos(angle) * radius - 2.5, y + sin(angle) * radius * 0.55 - 2.5, 5, 5,
                 palette[i % palette.count], alpha)
        }
    }

    private func drawResult(_ sim: Simulation) {
        guard sim.phase == .won || sim.phase == .retry else { return }
        let eased = 1 - (1 - impact) * (1 - impact)
        let glowAlpha = (70 + 110 * (1 - eased)) / 255
        let glowScale = 1.5 - 0.35 * eased
        if sim.phase == .retry {
            guard let hit = sim.people.first(where: { $0.walker.id == sim.collapsedWalkerId }) else { return }
            let x = CGFloat(hit.x) * 360, y = CGFloat(hit.y) * 410
            c.beginTransparencyLayer(auxiliaryInfo: nil)
            rect(0, 0, 360, 460, 0, 150 / 255 * min(1, impact * 3))
            reveal(LocatedArt(id: hit.walker.sprite, x: x - 15, y: y - 38,
                              width: 30, height: 42, flipped: false),
                   tint: 0xF27A6B, alpha: glowAlpha, scale: glowScale)
            if let impactedCar { reveal(impactedCar, tint: 0xF27A6B, alpha: glowAlpha, scale: glowScale) }
            c.endTransparencyLayer()
            burst(x, y - 17, eased: eased, palette: [0xF27A6B, 0xFFE07A])
        } else {
            c.beginTransparencyLayer(auxiliaryInfo: nil)
            rect(0, 0, 360, 460, 0, 160 / 255 * min(1, impact * 3))
            for person in sim.people {
                let x = CGFloat(person.x) * 360, y = CGFloat(person.y) * 410
                reveal(LocatedArt(id: "\(person.walker.sprite)_w\(Int(person.y * 32) % 3)",
                                  x: x - 15, y: y - 38, width: 30, height: 42, flipped: false),
                       tint: 0xFFE07A, alpha: glowAlpha, scale: glowScale)
                c.clear(CGRect(x: x + 1, y: max(y - 40, 26) - 19, width: 26, height: 25))
            }
            c.endTransparencyLayer()
            for person in sim.people {
                burst(CGFloat(person.x) * 360, CGFloat(person.y) * 410 - 17, eased: eased,
                      palette: [0xFFE07A, 0x88D498])
            }
        }
    }

    private func drawNight() {
        let space = CGColorSpaceCreateDeviceRGB()
        let maskColors = [color(0xFFFFFF).cgColor, color(0xFFFFFF, 130 / 255).cgColor, color(0xFFFFFF, 0).cgColor]
        let glowColors = [color(0xFFE07A, 130 / 255).cgColor, color(0xFFE07A, 55 / 255).cgColor, color(0xFFE07A, 0).cgColor]
        let mask = CGGradient(colorsSpace: space, colors: maskColors as CFArray, locations: [0, 0.55, 1])
        let warmGlow = CGGradient(colorsSpace: space, colors: glowColors as CFArray, locations: [0, 0.6, 1])

        func drawGradient(_ gradient: CGGradient?, mode: CGBlendMode) {
            guard let gradient else { return }
            for light in lights {
                c.saveGState()
                c.translateBy(x: light.x, y: light.y)
                c.scaleBy(x: light.rx, y: light.ry)
                c.setBlendMode(mode)
                c.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                     endCenter: .zero, endRadius: 1, options: [])
                c.restoreGState()
            }
        }

        c.beginTransparencyLayer(auxiliaryInfo: nil)
        c.setFillColor(color(0x1B2440, 155 / 255).cgColor)
        c.fill(board)
        drawGradient(mask, mode: .destinationOut)
        c.endTransparencyLayer()
        drawGradient(warmGlow, mode: .normal)
        for light in scenery.lights {
            rect(light.x, light.y, light.width, light.height, light.color, 210 / 255)
        }
    }
}
