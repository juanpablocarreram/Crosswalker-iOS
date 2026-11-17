import SwiftUI

private struct ModalActionKey: EnvironmentKey {
  static let defaultValue: (@escaping () -> Void) -> Void = { action in action() }
}
extension EnvironmentValues {
  var modalAction: (@escaping () -> Void) -> Void {
    get { self[ModalActionKey.self] }
    set { self[ModalActionKey.self] = newValue }
  }
}

struct PaperDialog<Content: View>: View {
  let title: String
  var dismissible = true
  var accent: Color = Palette.sky
  let dismiss: () -> Void
  @ViewBuilder let content: () -> Content
  @State private var visible = false
  @State private var closing = false
  @State private var scale: CGFloat = 0.9

  var body: some View {
    ZStack {
      Palette.inkShadow.opacity(0.52).ignoresSafeArea().onTapGesture {
        if dismissible { leave(dismiss) }
      }
      ViewThatFits(in: .vertical) {
        card
        ScrollView { card }.scrollIndicators(.hidden)
      }
      .frame(maxWidth: 400).padding(.horizontal, 22).padding(.vertical, 12)
      .scaleEffect(scale).opacity(visible ? 1 : 0)
      .allowsHitTesting(!closing).accessibilityHidden(closing)
      .accessibilityAddTraits(.isModal)
    }
    .task {
      withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.2)) { visible = true }
      withAnimation(.linear(duration: 0.12)) { scale = 1.05 }
      do { try await Task.sleep(nanoseconds: 120_000_000) } catch { return }
      guard !closing else { return }
      withAnimation(.linear(duration: 0.08)) { scale = 1 }
    }
    .accessibilityAction(.escape) { if dismissible { leave(dismiss) } }
  }

  private var card: some View {
    VStack(spacing: 16) {
      Spacer().frame(height: 4)
      content()
    }
    .font(Lettering.body()).foregroundStyle(Palette.ink)
    .padding(20).pixelPanel(Palette.paper, step: 4)
    .padding(.top, 8)
    .overlay(alignment: .topLeading) {
      Text(title).font(Lettering.hud())
        .multilineTextAlignment(.center).foregroundStyle(accent.readableText)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .pixelPanel(accent, step: 3).rotationEffect(.degrees(-4)).padding(.leading, 12)
    }
    .environment(\.modalAction, leave)
  }

  private func leave(_ action: @escaping () -> Void) {
    guard !closing else { return }
    closing = true
    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.14)) { visible = false }
    withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.14)) { scale = 0.94 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: action)
  }
}

struct ModalHost: View {
  @ObservedObject var session: Session
  private var key: String {
    if session.transitioning { return "" }
    if !session.dialog.isEmpty { return session.dialog }
    if session.paused && session.screen == .game { return "pause" }
    if let chosen = session.chosen { return "level-\(chosen.id)" }
    return session.showResult ? "result" : ""
  }

  var body: some View { modal.id(key) }

  @ViewBuilder private var modal: some View {
    if key == "settings" {
      PaperDialog(title: "A TU MANERA", dismiss: close) {
        Text("Pequeños ajustes para tu aventura").foregroundStyle(Palette.asphalt)
        Toggle("Sonidos", isOn: $session.sound)
        Toggle("Consejos en pantalla", isOn: $session.guidance)
        PaperButton("LISTO", action: close)
      }
    } else if key == "achievements" {
      PaperDialog(title: "MIS LOGROS", dismiss: close) {
        Text("★  \(session.totalStars) / 36 estrellas").font(Lettering.title()).foregroundStyle(
          Palette.goldDark)
        GeometryReader { proxy in
          Rectangle().fill(Palette.gold).frame(
            width: proxy.size.width * CGFloat(session.totalStars) / 36)
        }.frame(height: 8).padding(4).pixelPanel(Palette.asphalt)
        Text("\(session.completed) de 12 caminos seguros")
        ForEach(
          Array(
            [
              ("Primer paso", 1), ("Mi barrio seguro", 4), ("Gran planificador", 8),
              ("Guardián de la ciudad", 12),
            ].enumerated()), id: \.offset
        ) { _, item in
          let earned = session.completed >= item.1
          Text("\(earned ? "★" : "○")   \(item.0)").foregroundStyle(
            earned ? Palette.greenDark : Palette.kerb)
        }
        PaperButton("VOLVER", action: close)
      }
    } else if key == "resetProgress" {
      PaperDialog(title: "¿EMPEZAR DE NUEVO?", accent: Palette.gold, dismiss: close) {
        Text("Un nuevo camino te espera").font(Lettering.title(24))
        Text(
          "Se borrarán tus estrellas y logros. Solo quedará abierto el primer nivel y volverás a ver el tutorial. Esta acción no se puede deshacer."
        )
        Text("Tus ajustes de sonido y consejos se conservarán.").foregroundStyle(Palette.asphalt)
        PaperButton("CONSERVAR MI PROGRESO", action: close)
        PaperButton("↻  SÍ, REINICIAR", color: Palette.coral) { session.resetProgress() }
      }
    } else if key == "progressReset" {
      PaperDialog(title: "¡UN NUEVO COMIENZO!", accent: Palette.green, dismiss: close) {
        Text("Todo listo para tu primer cruce. Tus estrellas y logros vuelven a empezar.")
        PaperButton("▶\u{FE0E}  JUGAR DESDE EL INICIO") {
          close()
          session.enter(session.repo.levels[0])
        }
        PaperButton("VOLVER AL MENÚ", color: Palette.paper, action: close)
      }
    } else if key == "budget" {
      PaperDialog(
        title: session.remaining == 0 ? "NO TE QUEDAN FICHAS" : "NO TE ALCANZAN LAS FICHAS",
        accent: Palette.gold, dismiss: close
      ) {
        Text("Fichas disponibles: \(session.remaining) de \(session.level.budget)").font(
          Lettering.hud())
        Text(
          "Quita alguna habilidad o mejora de la calle para recuperar fichas e intenta de nuevo.")
        PaperButton("VOLVER AL PLAN", action: close)
      }
    } else if key.hasPrefix("tool:"),
      let tool = session.repo.tools.first(where: { "tool:" + $0.id == key })
    {
      PaperDialog(title: tool.label.uppercased(), dismiss: close) {
        ToolArtwork(id: tool.id)
        Text(
          "\(tool.cost) fichas · \(tool.category == "street" ? "Mejora compartida de la calle" : "Habilidad para un peatón")"
        )
        .font(Lettering.hud()).foregroundStyle(Palette.greenDark)
        Text(tool.explanation(session.level))
        PaperButton("ENTENDIDO", action: close)
      }
    } else if key == "campaignComplete" {
      PaperDialog(title: "¡GRACIAS POR COMPLETAR EL JUEGO!", accent: Palette.gold, dismiss: close) {
        PaperButton("SEGUIR JUGANDO", action: close)
      }
    } else if key == "pause" {
      PaperDialog(title: "PAUSA", accent: Palette.gold, dismiss: { session.paused = false }) {
        Text("Tu maqueta te espera.").foregroundStyle(Palette.asphalt)
        PaperButton("▶\u{FE0E}  CONTINUAR") { session.paused = false }
        PaperButton("↻  REINTENTAR", color: Palette.coral) { session.reset() }
        PaperButton("AJUSTES", color: Palette.paper) { session.dialog = "settings" }
        PaperButton("VOLVER AL MAPA", color: Palette.paper) { session.navigate(.map) }
      }
    } else if key.hasPrefix("level-"), let level = session.chosen {
      PaperDialog(title: "NIVEL \(level.id)", dismiss: { session.chosen = nil }) {
        Text(level.title).font(Lettering.title())
        Text("★ Llega al otro lado\n★★ Resuelve sin choques\n★★★ Usa pocas fichas")
        PaperButton("▶\u{FE0E}  PREPARAR EL PLAN") {
          session.chosen = nil
          session.enter(level)
        }
      }
    } else if key == "result", let sim = session.simulation {
      let won = sim.phase == .won
      let title = won ? "¡BUEN CAMINO!" : "OTRO PLAN, OTRA OPORTUNIDAD"
      PaperDialog(
        title: title, dismissible: false, accent: won ? Palette.green : Palette.coral, dismiss: {}
      ) {
        if won {
          PaperStars(count: sim.stars(session.cost), size: 52)
        } else {
          Text("↻").font(Lettering.title(52)).foregroundStyle(Palette.goldDark)
        }
        Text(
          won
            ? "¡Todos llegaron a salvo!"
            : sim.collapsedWalkerId == nil
              ? "Necesitamos un plan más seguro." : "¡Cuidado! Hubo un choque."
        ).font(Lettering.title(24))
        Text(
          won
            ? "Usaste \(session.cost) de \(session.level.budget) fichas. Tus buenas decisiones hacen una ciudad más segura."
            : sim.reason)
        if won, let next = session.repo.nextLevel(after: session.level.id) {
          PaperButton("SIGUIENTE CAMINO  →") { session.enter(next) }
        }
        PaperButton(
          won ? "VOLVER A INTENTAR" : "✎  MEJORAR MI PLAN",
          color: won ? Palette.paper : Palette.green
        ) {
          session.resumePlanning()
        }
        PaperButton("VOLVER AL MAPA", color: Palette.paper) { session.navigate(.map) }
      }
    }
  }

  private func close() { session.dialog = "" }
}
