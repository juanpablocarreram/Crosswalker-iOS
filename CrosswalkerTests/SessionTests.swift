#if !SWIFT_PACKAGE
import XCTest
@testable import Crosswalker

final class SessionTests: XCTestCase {
    @MainActor private func session() throws -> Session {
        let suite = "CrosswalkerSessionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let repo = try GameRepository(defaults: defaults)
        repo.sound = false
        repo.tutorialDone = true
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
}
#endif
