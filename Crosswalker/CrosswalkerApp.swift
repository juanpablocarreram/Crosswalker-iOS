import SwiftUI

@main struct CrosswalkerApp: App {
  private let repository = Result {
    #if DEBUG
      if (ProcessInfo.processInfo.arguments.contains("--ui-test-reset")
          || ProcessInfo.processInfo.arguments.contains("--ui-test")),
        let defaults = UserDefaults(suiteName: "Crosswalker.UITests")
      {
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reset") {
          defaults.removePersistentDomain(forName: "Crosswalker.UITests")
        }
        return try GameRepository(defaults: defaults)
      }
    #endif
    return try GameRepository()
  }
  var body: some Scene {
    WindowGroup {
      switch repository {
      case .success(let repo): GameRoot(repo: repo)
      case .failure(let error):
        VStack {
          Text("No se pudo abrir la aventura.")
          Text(error.localizedDescription)
        }.padding()
      }
    }
  }
}

@MainActor struct GameRoot: View {
  @StateObject private var session: Session
  @Environment(\.scenePhase) private var scenePhase
  init(repo: GameRepository) { _session = StateObject(wrappedValue: Session(repo: repo)) }
  var body: some View {
    ZStack {
      PaperBackground().ignoresSafeArea()
      ScreenTransitions(session: session)
        .accessibilityHidden(
          !session.dialog.isEmpty || session.paused || session.chosen != nil || session.showResult)
      ModalHost(session: session)
    }
    .font(Lettering.body())
    .foregroundStyle(Palette.ink)
    .tint(Palette.green)
    .preferredColorScheme(.light)
    .task(id: scenePhase) {
      session.setActive(scenePhase == .active)
      guard scenePhase == .active else { return }
      await session.runFrames()
    }
  }
}
