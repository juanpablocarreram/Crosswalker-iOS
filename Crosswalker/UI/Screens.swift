import SwiftUI

struct ScreenContent: View {
    @ObservedObject var session: Session
    var body: some View {
        ZStack {
            PaperBackground()
            switch session.screen {
            case .home:
                HomeScreen(session: session)
            case .map:
                WorldMap(session: session)
            case .game:
                Game(session: session).id(session.level.id)
            case .credits:
                CampaignCreditsScreen {
                    session.beep()
                    session.navigate(.home)
                }
            }
        }
    }
}

struct WorldMap: View {
    @ObservedObject var session: Session
    @State private var direction: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                PaperButton("‹ INICIO", color: Palette.paper) { session.beep(); session.navigate(.home) }
                    .accessibilityHint("Volver al inicio")
                VStack(spacing: 2) {
                    Text("\(session.completed) / \(session.repo.levels.count)")
                        .font(Lettering.title(24)).foregroundStyle(Palette.goldLight)
                    Text("Niveles completados").font(Lettering.body().weight(.semibold))
                        .foregroundStyle(Palette.cream).multilineTextAlignment(.center)
                }.padding(.horizontal, 8).padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .pixelPanel(Palette.asphalt, highlight: Palette.edge, shade: Palette.inkShadow)
            }
            Text(session.repo.worlds[session.world]).font(Lettering.title()).foregroundStyle(Palette.ink)
            HStack(spacing: 8) {
                ForEach(session.repo.worlds.indices, id: \.self) { world in
                    CraftChip(selected: session.world == world, action: { switchWorld(world) }) {
                        Text("MUNDO \(world + 1)")
                    }
                }
            }
            ZStack {
                levelList(world: session.world)
                    .id(session.world)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .offset(x: direction * 54).combined(with: .opacity),
                        removal: .offset(x: -direction * 54).combined(with: .opacity)
                    ))
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).clipped()
        }.padding(20)
    }

    private func switchWorld(_ world: Int) {
        guard world != session.world else { return }
        direction = world > session.world ? 1 : -1
        withAnimation(.easeInOut(duration: 0.28)) { session.changeWorld(world) }
    }

    private func levelList(world: Int) -> some View {
        ScrollView {
            let levels = session.repo.levels.filter { $0.world == world }
            VStack(spacing: 18) {
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    levelCard(level, index: index)
                    if index < levels.count - 1 {
                        Canvas { context, size in
                            let x = size.width * (index % 2 == 0 ? 0.27 : 0.72)
                            let other = size.width - x
                            let path = Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addCurve(to: CGPoint(x: other, y: size.height),
                                              control1: CGPoint(x: x, y: size.height * 0.8),
                                              control2: CGPoint(x: other, y: size.height * 0.2))
                            }
                            context.stroke(path, with: .color(Palette.coral), lineWidth: 2)
                        }.frame(height: 20)
                    }
                }
            }.padding(.vertical, 5)
        }
    }

    private func levelCard(_ level: Level, index: Int) -> some View {
        let unlocked = session.repo.unlocked(level.id)
        let scenery = level.world == 1 ? "decor_building_campus" : index % 2 == 0 ? "house" : "tree"
        return Button {
            guard session.world == level.world else { return }
            session.beep()
            session.chosen = level
        } label: {
            HStack(spacing: 16) {
                Text("\(level.id)").font(Lettering.title())
                    .foregroundStyle(unlocked ? Palette.ink : Palette.kerbLight)
                    .frame(width: 60, height: 60).background(unlocked ? Palette.kraft : Palette.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text(level.title).font(Lettering.body().weight(.semibold))
                        .foregroundStyle(unlocked ? Palette.ink : Palette.kerbLight)
                    if unlocked { PaperStars(count: session.repo.stars(level.id)) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if unlocked {
                    Artwork(scenery, size: 38).rotationEffect(.degrees(3))
                } else {
                    PixelLock().frame(width: 38, height: 38).accessibilityHidden(true)
                }
            }.padding(16).pixelPanel(unlocked ? Palette.paper : Palette.asphalt,
                                     highlight: unlocked ? Palette.cream : Palette.edge,
                                     shade: unlocked ? Palette.kraft : Palette.inkShadow)
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityLabel(unlocked ? level.title : "Nivel \(level.id), \(level.title), no disponible")
        .rotationEffect(.degrees(index % 2 == 0 ? -1 : 1))
        .padding(index % 2 == 0 ? .trailing : .leading, 35)
    }
}

private struct PixelLock: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 19
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x*unit, y: y*unit, width: w*unit, height: h*unit)), with: .color(color))
            }
            rect(6, 2, 7, 2, Palette.kerbLight)
            rect(5, 4, 2, 5, Palette.kerbLight)
            rect(12, 4, 2, 5, Palette.kerbLight)
            rect(3, 8, 13, 9, Palette.kerb)
            rect(9, 11, 1, 3, Palette.ink)
        }
    }
}

struct Game: View {
    @ObservedObject var session: Session
    private var planning: Bool { session.simulation == nil }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Board(session: session).frame(width: geometry.size.width, height: geometry.size.height)
                    .tutorialFrame("board")
                VStack(spacing: 0) {
                    hud
                    if planning {
                        if session.guidance || session.tutorialActive ||
                            (!session.level.tutorial && session.level.introLines.indices.contains(session.introIndex)) {
                            PlanningDialogue(session: session).padding(.horizontal, 14).padding(.vertical, 8)
                        }
                        Spacer(minLength: 0)
                        planPanel(maxHeight: geometry.size.height * 0.43)
                    } else {
                        Spacer(minLength: 0)
                        if let sim = session.simulation, !session.level.tutorial {
                            Text(sim.feedback.isEmpty ? "Observa cada carril: los coches necesitan tiempo y espacio para detenerse." : sim.feedback)
                                .font(Lettering.body())
                                .foregroundStyle(Palette.ink)
                                .padding(8).pixelPanel(Palette.paper.opacity(0.9)).padding(14)
                        }
                    }
                }
            }
            .overlayPreferenceValue(TutorialFrames.self) { frames in
                GeometryReader { proxy in
                    if let target = session.tutorialTarget, let spotlight = frames[target.spotlight] {
                        TutorialVeil(spotlight: proxy[spotlight], tapFrame: frames[target.tap].map { proxy[$0] })
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private var hud: some View {
        HStack(alignment: .top) {
            Button {
                session.paused = true
            } label: {
                Text("Ⅱ").font(Lettering.title(24)).foregroundStyle(Palette.cream)
                    .frame(width: 44, height: 44)
                    .pixelPanel(Palette.asphalt, highlight: Palette.edge, shade: Palette.inkShadow)
            }.buttonStyle(.plain).accessibilityLabel("Pausa").tutorialFrame("pause")
                .disabled(!session.permits("pause"))
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<session.level.budget, id: \.self) { index in
                    Circle().fill(index < session.remaining ? Palette.gold : Palette.inkShadow)
                        .overlay(Circle().strokeBorder(index < session.remaining ? Palette.goldLight : Palette.edge, lineWidth: 1))
                        .frame(width: 10, height: 10)
                }
                Text("\(session.remaining)/\(session.level.budget)").font(Lettering.hud())
                    .foregroundStyle(Palette.cream)
            }.padding(8).pixelPanel(Palette.asphalt, highlight: Palette.edge, shade: Palette.inkShadow)
                .accessibilityLabel("Fichas disponibles: \(session.remaining) de \(session.level.budget)")
                .tutorialFrame("tokens")
        }.padding(10)
    }

    private func planPanel(maxHeight: CGFloat) -> some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.24)) { session.togglePanel() }
            } label: {
                HStack(spacing: 8) {
                    Text("▲").rotationEffect(.degrees(session.planningPanelOpen ? 180 : 0))
                        .frame(width: 26, height: 26).foregroundStyle(Palette.ink)
                        .background(Palette.goldLight, in: RoundedRectangle(cornerRadius: 5))
                    Text(session.planningPanelOpen ? "CERRAR PLAN" : "ABRIR PLAN").font(Lettering.hud())
                    if !session.planningPanelOpen && !session.tutorialActive {
                        Artwork("pointer_hand", size: 25)
                    }
                }.padding(.horizontal, 12).frame(minHeight: 48)
                    .foregroundStyle(session.planningPanelOpen ? Palette.cream : Palette.ink)
                    .pixelPanel(session.planningPanelOpen ? Palette.asphalt : Palette.gold,
                                highlight: session.planningPanelOpen ? Palette.edge : Palette.goldLight,
                                shade: session.planningPanelOpen ? Palette.inkShadow : Palette.goldDark)
            }.buttonStyle(.plain).tutorialFrame("planning_panel")
                .disabled(!session.permits("planning_panel"))
            if session.planningPanelOpen {
                ScrollView {
                    planningControls.padding(.horizontal, 10).padding(.vertical, 8)
                }.frame(height: min(maxHeight, 226))
                    .pixelPanel(Palette.ink.opacity(0.78), highlight: Palette.edge, shade: Palette.inkShadow, step: 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            PaperButton("▶  PONER EL PLAN EN MARCHA", color: Palette.gold, enabled: session.permits("launch")) {
                session.launch()
            }.frame(maxWidth: 304).tutorialFrame("launch")
        }.padding(.horizontal, 14).padding(.bottom, 8)
    }

    private var planningControls: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(session.level.walkers) { walker in
                        let selected = walker.id == session.selected
                        let skills = session.plan.people[walker.id]?.skills ?? []
                        CraftChip(selected: selected, fill: selected ? Palette.paper : Palette.asphalt,
                                  action: { session.selectWalker(walker.id) }) {
                            HStack(spacing: 5) {
                                WalkerPortrait(walker: walker, skills: skills, size: 28,
                                               child: session.level.showsChildBadge(walker))
                                Text(walker.name + (skills.isEmpty ? "" : " ✓"))
                            }
                        }.disabled(!session.permits("walkers"))
                    }
                }
            }.tutorialFrame("walkers")
            HStack(spacing: 4) {
                Text("Cruce").font(Lettering.hud()).foregroundStyle(Palette.cream).padding(.trailing, 4)
                ForEach(0..<3, id: \.self) { index in
                    crossingButton(index)
                }
            }.tutorialFrame("crossing")
            HStack(spacing: 4) {
                tabButton("skill", "HABILIDADES")
                tabButton("street", "LA CALLE")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(session.repo.tools.filter { $0.category == session.tab && session.level.tools.contains($0.id) }) { tool in
                        toolCard(tool)
                    }
                }.padding(.bottom, 3)
            }.id(session.tab)
        }
    }

    private func crossingButton(_ index: Int) -> some View {
        let blocked = session.level.blockedCrossing == index
        let marked = session.level.night && !session.level.pedestrianCrossings.isEmpty && !blocked
        let selected = session.plan.people[session.selected]?.crossing == index
        return CraftChip(selected: selected, action: {
            session.crossing(index, fromBoard: false)
            session.beep()
        }) {
            VStack(spacing: 0) {
                Text(blocked ? "Cerrado" : ["Izq.", "Centro", "Der."][index])
                if marked { Text(session.level.hasMarkedCrossing(index) ? "Con paso" : "Sin paso").font(Lettering.hud(11)) }
            }.frame(maxWidth: .infinity)
        }.disabled(blocked || !session.permits("crossing"))
    }

    private func tabButton(_ tab: String, _ label: String) -> some View {
        let selected = session.tab == tab
        return CraftChip(selected: selected, action: {
            withAnimation(.easeInOut(duration: 0.16)) { session.tab = tab }
            session.beep()
        }) {
            HStack(spacing: 4) {
                if tab == "street" { Artwork("house", size: 18) }
                Text(label).lineLimit(1)
            }.frame(maxWidth: .infinity)
        }
        .disabled(!session.permits("tab_" + tab))
        .overlay {
            if session.guideTool?.category == tab && !selected {
                PixelPanelShape(step: 4).stroke(Palette.gold, lineWidth: 2).allowsHitTesting(false)
            }
        }
        .tutorialFrame("tab_" + tab)
    }

    private func toolCard(_ tool: Tool) -> some View {
        let active = tool.category == "street" ? session.plan.street.contains(tool.id) : session.skills.contains(tool.id)
        return VStack(spacing: 3) {
            Button {
                session.toggle(tool)
                session.beep()
            } label: {
                VStack(spacing: 2) {
                    HStack {
                        ToolArtwork(id: tool.id)
                        Spacer()
                        Text(active ? "✓ \(tool.cost)" : "\(tool.cost) ●")
                            .font(Lettering.hud())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(active ? Palette.green : Palette.goldLight, in: RoundedRectangle(cornerRadius: 4))
                    }.padding(.horizontal, 3)
                    Text(tool.label.uppercased()).font(Lettering.hud())
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 34)
                }.foregroundStyle(Palette.ink)
            }.buttonStyle(.plain).disabled(!session.permits("tool_" + tool.id))
                .accessibilityAddTraits(active ? .isSelected : []).tutorialFrame("tool_" + tool.id)
            Button {
                session.beep()
                session.dialog = "tool:" + tool.id
            } label: {
                Text("¿Para qué sirve?").font(Lettering.hud()).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 48).pixelPanel(Palette.skyLight)
            }.buttonStyle(.plain).disabled(!session.permits("tool_help"))
                .accessibilityLabel("Explicar " + tool.label)
        }.padding(5).frame(width: 124)
            .pixelPanel(active ? Palette.greenLight : Palette.cream,
                        shade: active ? Palette.greenDark : Palette.kraft, step: 6)
            .overlay {
                if session.guideTool?.id == tool.id {
                    PixelPanelShape(step: 6).stroke(Palette.gold, lineWidth: 2).allowsHitTesting(false)
                }
            }
    }
}

private struct PlanningDialogue: View {
    @ObservedObject var session: Session
    @State private var visibleCount = 0
    @State private var typing: Task<Void, Never>?
    private var text: String { session.guideMessage }
    private var speaker: Walker { session.level.tutorial ? session.walker : session.level.walkers[0] }
    private var speakerColor: Color {
        switch speaker.sprite {
        case "walker_coral": Palette.coral
        case "walker_green": Palette.green
        case "walker_rust": Palette.gold
        default: Palette.sky
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            WalkerPortrait(walker: speaker, skills: session.plan.people[speaker.id]?.skills ?? [],
                           size: 48, child: session.level.showsChildBadge(speaker))
            Button(action: advance) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker.name).font(Lettering.hud()).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(speakerColor)
                        .rotationEffect(.degrees(-3))
                    Text(String(text.prefix(visibleCount))).font(Lettering.body())
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottomTrailing) {
                            if !session.tutorialActive && session.introIndex < session.level.introLines.count - 1 {
                                Text("▼").font(Lettering.hud(10)).foregroundStyle(Palette.coralDark)
                            }
                        }
                }.padding(8).pixelPanel()
            }.buttonStyle(.plain).accessibilityLabel(text)
                .accessibilityHint(visibleCount < text.count ? "Toca para revelar el texto" : "Toca para avanzar")
        }.tutorialFrame("dialogue")
            .onAppear(perform: start)
            .onChange(of: text) { _ in start() }
            .onDisappear { typing?.cancel(); session.setDialogueVoice(false) }
    }

    private func start() {
        typing?.cancel()
        visibleCount = 0
        let count = text.count
        typing = Task { @MainActor in
            session.setDialogueVoice(true)
            for i in 1...max(1, count) {
                do { try await Task.sleep(nanoseconds: 15_000_000) } catch { return }
                visibleCount = i
            }
            session.setDialogueVoice(false)
        }
    }

    private func advance() {
        guard session.permits("dialogue") else { return }
        if visibleCount < text.count {
            typing?.cancel()
            visibleCount = text.count
            session.setDialogueVoice(false)
        } else {
            withAnimation(.easeInOut(duration: 0.22)) { session.advanceDialogue() }
        }
    }
}

private struct TutorialFrames: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private extension View {
    func tutorialFrame(_ id: String) -> some View {
        anchorPreference(key: TutorialFrames.self, value: .bounds) { [id: $0] }
    }
}

private struct TutorialVeil: View {
    let spotlight: CGRect
    let tapFrame: CGRect?
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let wave = CGFloat(sin(phase * 6))
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let window = spotlight.insetBy(dx: -4, dy: -4)
                    var mask = Path(CGRect(origin: .zero, size: size))
                    mask.addRoundedRect(in: window, cornerSize: CGSize(width: 7, height: 7))
                    context.fill(mask, with: .color(Palette.inkShadow.opacity(0.68)), style: FillStyle(eoFill: true))
                    context.stroke(Path(roundedRect: window, cornerRadius: 7),
                                   with: .color(Palette.goldLight.opacity(0.8)), lineWidth: 2)
                }
                if let tap = tapFrame {
                    Artwork("pointer_hand", size: 30)
                        .position(x: max(19, tap.maxX - 18), y: tap.midY + wave * 4)
                }
            }
        }
    }
}
