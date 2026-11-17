import XCTest

#if SWIFT_PACKAGE
  @testable import CrosswalkerCore
#else
  @testable import Crosswalker
#endif

final class SessionTests: XCTestCase {
  @MainActor private func session(tutorialDone: Bool = true) throws -> Session {
    let suite = "CrosswalkerSessionTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: Self.self)
    #endif
    let url = try XCTUnwrap(
      bundle.url(forResource: "campaign", withExtension: "json", subdirectory: "Fixtures"))
    let campaign = try JSONDecoder().decode(Campaign.self, from: Data(contentsOf: url))
    let repo = GameRepository(campaign: campaign, defaults: defaults)
    repo.sound = false
    repo.tutorialDone = tutorialDone
    return Session(repo: repo)
  }

  @MainActor func testLevelOneStartsAtConfiguredCrossingAndCanUnlockNextLevel() throws {
    let s = try session()
    XCTAssertTrue(s.repo.unlocked(1))
    XCTAssertFalse(s.repo.unlocked(2))
    s.enter(s.repo.levels[1])
    XCTAssertEqual(s.screen, .home)
    s.enter(s.repo.levels[0])
    XCTAssertEqual(s.plan.people[s.selected]?.crossing, s.level.initialCrossings[0])
    s.crossing(1, fromBoard: false)
    s.toggle(try XCTUnwrap(s.repo.tools.first { $0.id == "look" }))
    s.launch()
    for _ in 0..<1801 { s.tick() }
    XCTAssertTrue(s.simulation?.phase == .won)
    XCTAssertEqual(s.repo.stars(1), 3)
    XCTAssertTrue(s.repo.unlocked(2))
    s.enter(s.repo.levels[1])
    XCTAssertEqual(s.level.id, 2)
  }

  @MainActor func testBudgetAndWalkerSwapAtLevelFive() throws {
    let s = try session()
    s.repo.save(4, stars: 2)
    s.enter(s.repo.levels[4])
    let slow = try XCTUnwrap(s.repo.tools.first { $0.id == "speed_zone" })
    let escort = try XCTUnwrap(s.repo.tools.first { $0.id == "escort" })
    s.toggle(slow)
    let cost = s.cost
    s.toggle(escort)
    s.selectWalker("tomas")
    let initialAna = s.plan.people["ana"]?.crossing
    let initialTomas = s.plan.people["tomas"]?.crossing
    s.crossing(try XCTUnwrap(initialAna), fromBoard: false)
    XCTAssertEqual(s.plan.people["tomas"]?.crossing, initialAna)
    XCTAssertEqual(s.plan.people["ana"]?.crossing, initialTomas)
    s.toggle(try XCTUnwrap(s.repo.tools.first { $0.id == "phone_away" }))
    s.toggle(try XCTUnwrap(s.repo.tools.first { $0.id == "look" }))
    XCTAssertEqual(s.dialog, "budget")
    s.toggle(slow)
    XCTAssertLessThan(s.cost, s.level.budget)
    XCTAssertGreaterThan(cost, 0)
  }

  @MainActor func testPauseAndTransitionFreezeSimulation() throws {
    let s = try session()
    s.enter(s.repo.levels[0])
    s.launch()
    s.paused = true
    s.tick()
    XCTAssertEqual(s.simulation?.time, 0)
    s.paused = false
    s.transitioning = true
    s.tick()
    XCTAssertEqual(s.simulation?.time, 0)
    s.transitioning = false
    s.tick()
    XCTAssertEqual(s.simulation?.time, Simulation.step)
  }

  @MainActor func testResetClearsUnlocksButKeepsPreferences() throws {
    let s = try session()
    s.repo.save(1, stars: 3)
    s.guidance = false
    s.resetProgress()
    XCTAssertTrue(s.repo.unlocked(1))
    XCTAssertFalse(s.repo.unlocked(2))
    XCTAssertFalse(s.repo.tutorialDone)
    XCTAssertFalse(s.repo.sound)
    XCTAssertFalse(s.repo.guidance)
  }
  @MainActor func testTutorialAllowsPausePanelAndHelpThroughoutTheGuide() throws {
    let s = try session(tutorialDone: false)
    s.enter(s.repo.levels[0])
    XCTAssertEqual(s.tutorialTarget?.spotlight, "planning_panel")
    XCTAssertTrue(s.permits("pause"))
    XCTAssertTrue(s.permits("planning_panel"))
    XCTAssertFalse(s.permits("launch"))
    s.togglePanel()
    s.advanceDialogue()
    s.advanceDialogue()
    XCTAssertEqual(s.introIndex, 2)
    XCTAssertFalse(s.planningPanelOpen)
    XCTAssertEqual(s.tutorialTarget?.spotlight, "board")
    s.togglePanel()
    while s.introIndex < s.level.introLines.count - 1 { s.advanceDialogue() }
    s.crossing(1, fromBoard: false)
    XCTAssertEqual(s.tutorialTarget?.tap, "tool_look")
    XCTAssertTrue(s.permits("tool_help"))
    s.toggle(try XCTUnwrap(s.repo.tools.first { $0.id == "look" }))
    XCTAssertTrue(s.permits("launch"))
    s.launch()
    XCTAssertTrue(s.repo.tutorialDone)
    XCTAssertNil(s.tutorialTarget)
  }

  @MainActor func testWinningFinalLevelShowsCreditsAfterResultDelay() async throws {
    let s = try session()
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: Self.self)
    #endif
    let url = try XCTUnwrap(
      bundle.url(forResource: "trajectories", withExtension: "json", subdirectory: "Fixtures"))
    let cases = try JSONDecoder().decode([WinningPlan].self, from: Data(contentsOf: url))
    let solution = try XCTUnwrap(cases.first { $0.level == 12 && $0.stars > 0 })
    s.repo.save(11, stars: 3)
    s.enter(s.repo.levels[11])
    s.plan = Plan(
      people: Dictionary(
        uniqueKeysWithValues: zip(s.level.walkers, solution.crossings).map { walker, crossing in
          (walker.id, Assignment(crossing: crossing, skills: Set(solution.skills[walker.id] ?? [])))
        }), street: Set(solution.street))
    s.launch()
    for _ in 0..<1801 { s.tick() }
    XCTAssertEqual(s.simulation?.phase, .won)
    XCTAssertEqual(s.screen, .game)
    XCTAssertFalse(s.showResult)
    try await Task.sleep(nanoseconds: 1_100_000_000)
    XCTAssertEqual(s.screen, .credits)
    s.navigate(.home)
    XCTAssertEqual(s.dialog, "campaignComplete")
    XCTAssertGreaterThan(s.repo.stars(12), 0)
  }

  @MainActor func testReturningToPlanningCancelsPendingResult() async throws {
    let s = try session()
    s.enter(s.repo.levels[0])
    s.toggle(try XCTUnwrap(s.repo.tools.first { $0.id == "look" }))
    s.crossing(1, fromBoard: false)
    s.launch()
    for _ in 0..<1801 { s.tick() }
    XCTAssertEqual(s.simulation?.phase, .won)
    s.resumePlanning()
    try await Task.sleep(nanoseconds: 1_100_000_000)
    XCTAssertNil(s.simulation)
    XCTAssertFalse(s.showResult)
  }

  @MainActor func testSceneFrameTaskAdvancesAndStopsWhenCancelled() async throws {
    let s = try session()
    s.enter(s.repo.levels[0])
    s.toggle(try XCTUnwrap(s.repo.tools.first { $0.id == "look" }))
    s.crossing(1, fromBoard: false)
    s.launch()
    s.setActive(true)
    let loop = Task { await s.runFrames() }
    try await Task.sleep(nanoseconds: 250_000_000)
    XCTAssertGreaterThan(try XCTUnwrap(s.simulation?.time), 0)
    loop.cancel()
    await loop.value
    let stopped = s.simulation?.time
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(s.simulation?.time, stopped)
    s.setActive(false)
    XCTAssertTrue(s.paused)
    s.setActive(true)
    s.paused = false
    let resumed = Task { await s.runFrames() }
    try await Task.sleep(nanoseconds: 150_000_000)
    resumed.cancel()
    await resumed.value
    XCTAssertGreaterThan(try XCTUnwrap(s.simulation?.time), try XCTUnwrap(stopped))
  }

  private struct WinningPlan: Decodable {
    let level: Int
    let stars: Int
    let crossings: [Int]
    let skills: [String: [String]]
    let street: [String]
  }

}
