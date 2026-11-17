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
        PaperButton("‹ INICIO", color: Palette.paper) {
          session.beep()
          session.navigate(.home)
        }
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
          .transition(
            reduceMotion
              ? .opacity
              : .asymmetric(
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
                path.addCurve(
                  to: CGPoint(x: other, y: size.height),
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
      }.padding(16).pixelPanel(
        unlocked ? Palette.paper : Palette.asphalt,
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
        context.fill(
          Path(CGRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit)),
          with: .color(color))
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
  @State private var controlsHeight: CGFloat = 0

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Board(session: session).frame(width: geometry.size.width, height: geometry.size.height)
          .tutorialFrame("board")
        VStack(spacing: 0) {
          hud
          if planning {
            if session.guidance || session.tutorialActive
              || (!session.level.tutorial
                && session.level.introLines.indices.contains(session.introIndex))
            {
              PlanningDialogue(session: session).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14).padding(.vertical, 8)
            }
            GeometryReader { remaining in
              planPanel(maxHeight: remaining.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
          } else {
            Spacer(minLength: 0)
            if let sim = session.simulation, !session.level.tutorial {
              Text(
                sim.feedback.isEmpty
                  ? "Observa cada carril: los coches necesitan tiempo y espacio para detenerse."
                  : sim.feedback
              )
              .font(Lettering.body())
              .foregroundStyle(Palette.ink)
              .padding(8).pixelPanel(Palette.paper.opacity(0.9)).padding(14)
            }
          }
        }
      }
      .overlayPreferenceValue(TutorialFrames.self) { frames in
        GeometryReader { proxy in
          if let target = session.tutorialTarget, frames[target.spotlight == "crossing" ? "crossing_0" : target.spotlight] != nil {
            ZStack(alignment: .topLeading) {
              Color.black.opacity(0.40)
              if target.spotlight == "board", let board = frames["board"] {
                let rect = proxy[board.anchor]
                board.content.frame(width: rect.width, height: rect.height)
                  .mask(alignment: .top) {
                    Rectangle().frame(height: frames["planning_panel"].map { proxy[$0.anchor].minY } ?? rect.height)
                  }
                  .position(x: rect.midX, y: rect.midY)
                  .allowsHitTesting(false).accessibilityHidden(true)
              }
              ForEach((["dialogue", "pause", "planning_panel"]
                + (target.spotlight == "crossing" ? ["crossing_0", "crossing_1", "crossing_2"] : [target.spotlight])
                + (target.tap == "tool_look" ? ["tool_help"] : [])).reduce(into: [String]()) {
                if $1 != "board" && !$0.contains($1) { $0.append($1) }
              }, id: \.self) { id in
                if let entry = frames[id] {
                  let rect = proxy[entry.anchor]
                  entry.content.frame(width: rect.width, height: rect.height)
                    .colorMultiply(id == "tool_help" ? Color(white: 0.6) : .white)
                    .allowsHitTesting(true).accessibilityHidden(false)
                    .position(x: rect.midX, y: rect.midY)
                }
              }
              TutorialVeil(
                tapFrame: frames[target.tap == "crossing" ? "crossing_0" : target.tap].map { proxy[$0.anchor] },
                markedFrames: (target.spotlight == "dialogue" ? []
                  : target.spotlight == "board" ? ["planning_panel"]
                  : target.spotlight == "crossing" ? ["crossing_0", "crossing_1", "crossing_2"]
                  : [target.spotlight]).compactMap { frames[$0].map { proxy[$0.anchor] } },
                width: proxy.size.width
              ).allowsHitTesting(false).accessibilityHidden(true)
            }
          }
        }
      }
    }
    .environment(\.tutorialElevatedIDs, session.tutorialTarget.map {
      Set(["dialogue", "pause", "planning_panel"]
        + ($0.spotlight == "crossing" ? ["crossing_0", "crossing_1", "crossing_2"] : [$0.spotlight])
        + ($0.tap == "tool_look" ? ["tool_help"] : [])).subtracting(["board"])
    } ?? [])
  }

  private var hud: some View {
    HStack(alignment: .top) {
      Button {
        session.paused = true
      } label: {
        Text("Ⅱ").font(.system(size: 22)).foregroundStyle(Palette.ink)
          .frame(width: 48, height: 48)
          .pixelPanel(Palette.paper)
      }.buttonStyle(.plain).accessibilityLabel("Pausa").tutorialFrame("pause")
        .disabled(!session.permits("pause"))
      Spacer()
      VStack(spacing: 3) {
        HStack(spacing: 3) {
          ForEach(0..<session.level.budget, id: \.self) { index in
            let held = index < session.remaining
            Color.clear.frame(width: 11, height: 11)
              .pixelPanel(
                held ? Color(hex: 0xE8823A) : Palette.inkShadow,
                highlight: held ? Color(hex: 0xF7AE6B) : nil,
                shade: held ? Color(hex: 0xB35A24) : Palette.edge,
                shadow: nil)
          }
        }
        Text("FICHAS").font(Lettering.hud()).tracking(2).foregroundStyle(Palette.cream)
      }.padding(.horizontal, 8).padding(.vertical, 6)
        .pixelPanel(Palette.asphalt, highlight: Palette.edge, shade: Palette.inkShadow)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Te quedan \(session.remaining) de \(session.level.budget) fichas")
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
        }.padding(.leading, 12).padding(.trailing, session.planningPanelOpen ? 16 : 46).frame(minHeight: 48)
          .foregroundStyle(session.planningPanelOpen ? Palette.cream : Palette.ink)
          .pixelPanel(
            session.planningPanelOpen ? Palette.asphalt : Palette.gold,
            highlight: session.planningPanelOpen ? Palette.edge : Palette.goldLight,
            shade: session.planningPanelOpen ? Palette.inkShadow : Palette.goldDark)
      }.buttonStyle(.plain)
        .overlay(alignment: .trailing) {
          if !session.planningPanelOpen && !session.tutorialActive {
            Artwork("pointer_hand", size: 28).rotationEffect(.degrees(225))
              .padding(.trailing, 8).allowsHitTesting(false).accessibilityHidden(true)
          }
        }.tutorialFrame("planning_panel")
        .disabled(!session.permits("planning_panel"))
      if session.planningPanelOpen {
        ScrollView {
          planningControls.padding(.horizontal, 10).padding(.vertical, 8)
            .background {
              GeometryReader { measured in
                Color.clear.preference(key: PlanningControlsHeight.self, value: measured.size.height)
              }
            }
        }.frame(height: min(controlsHeight, max(0, maxHeight - 48 - 54 - 12 - 8)))
          .onPreferenceChange(PlanningControlsHeight.self) { controlsHeight = $0 }
          .background {
            Color.clear.pixelPanel(Palette.ink, highlight: Palette.edge, shade: Palette.inkShadow, step: 8).opacity(0.72)
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      Button { session.launch() } label: {
        HStack(spacing: 8) {
          Text("▶\u{FE0E}").font(Lettering.hud())
            .foregroundStyle(session.permits("launch") ? Palette.cream : Palette.ink)
            .frame(width: 28, height: 28)
            .background(Palette.ink.opacity(0.22), in: RoundedRectangle(cornerRadius: 5))
          Text("PONER EL PLAN EN MARCHA")
        }
      }.buttonStyle(PaperButtonStyle(color: Palette.green))
        .disabled(!session.permits("launch"))
        .frame(maxWidth: 304).accessibilityIdentifier("launch-plan").tutorialFrame("launch")
    }.padding(.horizontal, 14).padding(.bottom, 8)
  }

  private var planningControls: some View {
    VStack(spacing: 6) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 5) {
          ForEach(session.level.walkers) { walker in
            let selected = walker.id == session.selected
            let skills = session.plan.people[walker.id]?.skills ?? []
            CraftChip(
              selected: selected, fill: selected ? Palette.paper : Palette.asphalt,
              action: { session.selectWalker(walker.id) }
            ) {
              HStack(spacing: 5) {
                WalkerPortrait(
                  walker: walker, skills: skills, size: 28,
                  child: session.level.showsChildBadge(walker))
                Text(walker.name + (skills.isEmpty ? "" : " ✓"))
              }
            }.disabled(!session.permits("walkers")).accessibilityIdentifier("walker-" + walker.id)
          }
        }
      }.tutorialFrame("walkers")
      HStack(spacing: 4) {
        Text("Cruce").font(Lettering.hud()).foregroundStyle(Palette.cream).padding(.trailing, 4)
        ForEach(0..<3, id: \.self) { index in
          crossingButton(index)
        }
      }
      HStack(spacing: 4) {
        tabButton("skill", "HABILIDADES")
        tabButton("street", "LA CALLE")
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(
            session.repo.tools.filter {
              $0.category == session.tab && session.level.tools.contains($0.id)
            }
          ) { tool in
            toolCard(tool)
          }
        }.padding(.bottom, 3)
      }.id(session.tab).accessibilityIdentifier("tool-palette")
    }
  }

  private func crossingButton(_ index: Int) -> some View {
    let blocked = session.level.blockedCrossing == index
    let marked = session.level.night && !session.level.pedestrianCrossings.isEmpty && !blocked
    let selected = session.plan.people[session.selected]?.crossing == index
    return CraftChip(
      selected: selected,
      action: {
        session.crossing(index, fromBoard: false)
        session.beep()
      }
    ) {
      VStack(spacing: 0) {
        Text(blocked ? "Cerrado" : ["Izq.", "Centro", "Der."][index])
        if marked {
          Text(session.level.hasMarkedCrossing(index) ? "Con paso" : "Sin paso").font(
            Lettering.hud(11))
        }
      }.frame(maxWidth: .infinity)
    }.disabled(blocked || !session.permits("crossing"))
      .accessibilityIdentifier("crossing-\(index)").tutorialFrame("crossing_\(index)")
  }

  private func tabButton(_ tab: String, _ label: String) -> some View {
    let selected = session.tab == tab
    return CraftChip(
      selected: selected,
      action: {
        withAnimation(.easeInOut(duration: 0.16)) { session.tab = tab }
        session.beep()
      }
    ) {
      HStack(spacing: 4) {
        if tab == "street" { Artwork("house", size: 18) }
        Text(label).lineLimit(1)
      }.frame(maxWidth: .infinity)
    }
    .disabled(!session.permits("tab_" + tab))
    .accessibilityIdentifier("tab-" + tab)
    .overlay {
      if session.guideTool?.category == tab && !selected {
        PixelPanelShape(step: 4).stroke(Palette.gold, lineWidth: 2).allowsHitTesting(false)
      }
    }
    .tutorialFrame("tab_" + tab)
  }

  private func toolCard(_ tool: Tool) -> some View {
    let active =
      tool.category == "street"
      ? session.plan.street.contains(tool.id) : session.skills.contains(tool.id)
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
              .background(
                active ? Palette.green : Palette.goldLight, in: RoundedRectangle(cornerRadius: 4))
          }.padding(.horizontal, 3)
          Text(tool.label.uppercased()).font(Lettering.hud())
            .multilineTextAlignment(.center)
            .frame(minHeight: 34)
        }.foregroundStyle(Palette.ink)
      }.buttonStyle(.plain).disabled(!session.permits("tool_" + tool.id))
        .accessibilityIdentifier("tool-" + tool.id)
        .accessibilityAddTraits(active ? .isSelected : []).tutorialFrame("tool_" + tool.id)
      Button {
        session.beep()
        session.dialog = "tool:" + tool.id
      } label: {
        Text("¿Para qué sirve?").font(Lettering.hud()).foregroundStyle(Palette.ink)
          .frame(maxWidth: .infinity, minHeight: 48).pixelPanel(Palette.skyLight)
      }.buttonStyle(.plain).disabled(!session.permits("tool_help"))
        .accessibilityLabel("Explicar " + tool.label).tutorialFrame("tool_help")
    }.padding(5).frame(width: 124)
      .pixelPanel(
        active ? Palette.greenLight : Palette.cream,
        shade: active ? Palette.greenDark : Palette.kraft, step: 6
      )
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
    case "walker_chair": Color(hex: 0xE8823A)
    case "walker_slate": Palette.gold
    default: Palette.sky
    }
  }

  private var speakerHighlight: Color {
    switch speaker.sprite {
    case "walker_coral": Palette.coralLight
    case "walker_green": Palette.greenLight
    case "walker_chair": Color(hex: 0xF7AE6B)
    case "walker_slate": Palette.goldLight
    default: Palette.skyLight
    }
  }
  private var speakerShade: Color {
    switch speaker.sprite {
    case "walker_coral": Palette.coralDark
    case "walker_green": Palette.greenDark
    case "walker_chair": Color(hex: 0xB35A24)
    case "walker_slate": Palette.goldDark
    default: Palette.skyDark
    }
  }

  var body: some View {
    HStack(spacing: 8) {
      WalkerPortrait(
        walker: speaker, skills: session.plan.people[speaker.id]?.skills ?? [],
        size: 48, child: session.level.showsChildBadge(speaker))
      Button(action: advance) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .bottom, spacing: 0) {
            Text(markedText).font(Lettering.body())
              .transaction { $0.animation = nil }
              .foregroundStyle(Palette.ink)
              .frame(maxWidth: .infinity, alignment: .leading)
            if !session.tutorialActive {
              ZStack(alignment: .bottomTrailing) {
                Color.clear.frame(width: 32, height: 30)
                if visibleCount < text.utf16.count || session.introIndex < session.level.introLines.count - 1 {
                  DialogueTapHand().frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                }
              }
            }
          }
        }.padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 12)
          .pixelPanel(Palette.paper, step: 4, innerBorder: Palette.kraft)
          .overlay(alignment: .topLeading) {
            Text(speaker.name.uppercased()).font(Lettering.hud())
              .foregroundStyle(speakerColor.readableText)
              .padding(.horizontal, 8).padding(.vertical, 2)
              .pixelPanel(speakerColor, highlight: speakerHighlight, shade: speakerShade, step: 3)
              .rotationEffect(.degrees(-4)).offset(x: 8, y: -10)
              .accessibilityHidden(true)
          }
      }.buttonStyle(.plain).accessibilityIdentifier("planning-dialogue").accessibilityLabel(text)
        .accessibilityHint(
          visibleCount < text.utf16.count ? "Toca para revelar el texto" : "Toca para avanzar")
    }.tutorialFrame("dialogue")
      .onAppear(perform: start)
      .onChange(of: text) { _ in start() }
      .onDisappear {
        typing?.cancel()
        session.setDialogueVoice(false)
      }
  }

  private var markedText: AttributedString {
    var result = AttributedString(text)
    let lexicon = DialogueLexicon(level: session.level, tools: session.repo.tools)
    for match in lexicon.matches(in: text) {
      guard let range = Range(match.range, in: text),
        let start = AttributedString.Index(range.lowerBound, within: result),
        let end = AttributedString.Index(range.upperBound, within: result)
      else { continue }
      result[start..<end].font = Lettering.body().weight(.semibold)
      if NSMaxRange(match.range) <= visibleCount {
        let color: Color
        switch match.category {
        case .person: color = Palette.greenLight
        case .object: color = Palette.goldLight
        case .place: color = Palette.skyLight
        }
        let emphasis =
          visibleCount == text.utf16.count
          ? 0 : max(0, min(1, 1 - Double(visibleCount - NSMaxRange(match.range)) / 9))
        result[start..<end].backgroundColor = color.opacity(0.5 + 0.45 * emphasis)
      }
    }
    let prefix = String(decoding: text.utf16.prefix(visibleCount), as: UTF16.self)
    if let start = AttributedString.Index(
      String.Index(utf16Offset: prefix.utf16.count, in: text), within: result)
    {
      result[start..<result.endIndex].foregroundColor = .clear
    }
    return result
  }

  private func start() {
    typing?.cancel()
    visibleCount = 0
    let count = text.utf16.count
    typing = Task { @MainActor in
      session.setDialogueVoice(true)
      for i in 0..<count {
        do { try await Task.sleep(nanoseconds: PresentationTiming.dialogueNanoseconds) } catch {
          return
        }
        visibleCount = i + 1
        if visibleCount % 3 == 0 { session.dialogueBlip(speaker: speaker.id) }
      }
      session.setDialogueVoice(false)
    }
  }

  private func advance() {
    guard session.permits("dialogue") else { return }
    if session.tutorialActive {
      // Android's tutorial overlay dispatches the page action directly, including during typing.
      withAnimation(.easeInOut(duration: 0.22)) { session.advanceDialogue() }
    } else if visibleCount < text.utf16.count {
      typing?.cancel()
      visibleCount = text.utf16.count
      session.setDialogueVoice(false)
    } else {
      withAnimation(.easeInOut(duration: 0.22)) { session.advanceDialogue() }
    }
  }
}

private struct PlanningControlsHeight: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct TutorialRegion {
  let anchor: Anchor<CGRect>
  let content: AnyView
}

private struct TutorialFrames: PreferenceKey {
  static let defaultValue: [String: TutorialRegion] = [:]
  static func reduce(value: inout [String: TutorialRegion], nextValue: () -> [String: TutorialRegion]) {
    value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
  }
}

private struct TutorialElevationKey: EnvironmentKey {
  static let defaultValue: Set<String> = []
}

private extension EnvironmentValues {
  var tutorialElevatedIDs: Set<String> {
    get { self[TutorialElevationKey.self] }
    set { self[TutorialElevationKey.self] = newValue }
  }
}

private struct TutorialTarget: ViewModifier {
  let id: String
  let liftedContent: AnyView
  @Environment(\.tutorialElevatedIDs) private var elevated
  @Environment(\.isEnabled) private var enabled
  func body(content: Content) -> some View {
    // Keep one owner of dialogue typing/audio state. Lift only its rendered controls above the veil.
    Group {
      if elevated.contains(id) { content.hidden() } else { content }
    }
      .anchorPreference(key: TutorialFrames.self, value: .bounds) {
        [id: TutorialRegion(anchor: $0, content: AnyView(liftedContent.environment(\.isEnabled, enabled)))]
      }
  }
}

extension View {
  fileprivate func tutorialFrame(_ id: String) -> some View {
    modifier(TutorialTarget(id: id, liftedContent: AnyView(self)))
  }
}

private struct TutorialVeil: View {
  let tapFrame: CGRect?
  let markedFrames: [CGRect]
  let width: CGFloat

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
      let elapsed = timeline.date.timeIntervalSinceReferenceDate
      let pulse = CGFloat(elapsed.truncatingRemainder(dividingBy: 0.62) / 0.62)
      let cycle = elapsed.truncatingRemainder(dividingBy: 0.96)
      let press = cycle < 0.18 ? 0 : cycle < 0.40 ? (cycle - 0.18) / 0.22
        : cycle < 0.47 ? 1 : cycle < 0.73 ? 1 - (cycle - 0.47) / 0.26 : 0
      ZStack(alignment: .topLeading) {
        Canvas { context, size in
          for marked in markedFrames {
            let padding = 3 + 7 * pulse
            context.stroke(
              Path(roundedRect: marked.insetBy(dx: -padding, dy: -padding), cornerRadius: 8),
              with: .color(Palette.goldLight.opacity(1 - 0.54 * pulse)), lineWidth: 3)
          }
        }
        if let tap = tapFrame {
          let width: CGFloat = 42
          let retreat = width * 0.28 * (1 - press)
          let contact = CGPoint(
            x: min(max(0, tap.maxX - min(20, tap.width / 2)), max(0, self.width - 48)),
            y: max(48, tap.minY + min(14, tap.height / 2)))
          Artwork("pointer_hand", size: width)
            .rotationEffect(.degrees(225), anchor: UnitPoint(x: 0.36, y: 0.04))
            .position(x: contact.x + retreat + width * 0.14, y: contact.y - retreat + width * 0.46)
        }
      }
    }
  }
}

private struct DialogueTapHand: View {
  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30)) { tick in
      let cycle = tick.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.96)
      let press = cycle < 0.18 ? 0 : cycle < 0.40 ? (cycle - 0.18) / 0.22
        : cycle < 0.47 ? 1 : cycle < 0.73 ? 1 - (cycle - 0.47) / 0.26 : 0
      let retreat = 19 * 0.28 * (1 - press)
      Artwork("pointer_hand", size: 19)
        .rotationEffect(.degrees(225), anchor: UnitPoint(x: 0.36, y: 0.04))
        .offset(x: retreat, y: -retreat)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }.allowsHitTesting(false)
  }
}
