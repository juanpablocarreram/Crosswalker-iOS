import XCTest
#if SWIFT_PACKAGE
@testable import CrosswalkerCore
#else
@testable import Crosswalker
#endif

final class SimulationTests: XCTestCase {
    private var fixtureBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: Self.self)
        #endif
    }

    private func fixture<T: Decodable>(_ name: String) throws -> T {
        let url = try XCTUnwrap(fixtureBundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    func testMovingToAnOccupiedCrossingSwapsAssignmentsWithoutMovingSkills() {
        var plan = Plan(people: [
            "ana": Assignment(crossing: 1, skills: ["escort"]),
            "tomas": Assignment(crossing: 0)
        ])
        plan.moveWalker("ana", crossing: 0)
        XCTAssertEqual(plan.people["ana"]?.crossing, 0)
        XCTAssertEqual(plan.people["ana"]?.skills, ["escort"])
        XCTAssertEqual(plan.people["tomas"]?.crossing, 1)
    }

    func testDuplicateCrossingsAreRejectedBeforeMoving() throws {
        let campaign: Campaign = try fixture("campaign")
        let level = try XCTUnwrap(campaign.levels.first { $0.id == 5 })
        let assignments = Dictionary(uniqueKeysWithValues: level.walkers.map { ($0.id, Assignment(crossing: 1)) })
        let sim = Simulation(level, Plan(people: assignments))
        sim.tick()
        XCTAssertEqual(sim.time, 0)
        XCTAssertEqual(sim.phase, .retry)
        XCTAssertEqual(sim.reason, "Asigna un cruce diferente a cada peatón.")
    }

    func testSimulationKeepsItsOwnPlanSnapshot() throws {
        let campaign: Campaign = try fixture("campaign")
        var plan = Plan(people: ["ana": Assignment(crossing: 1, skills: ["look"])])
        let sim = Simulation(try XCTUnwrap(campaign.levels.first), plan)
        plan.people["ana"]?.skills = []
        XCTAssertEqual(sim.plan.people["ana"]?.skills, ["look"])
    }

    // Frame snapshots recorded by the Android v1 Kotlin simulation with the same campaign.
    func testAndroidReferenceTrajectories() throws {
        let campaign: Campaign = try fixture("campaign")
        let traces: [Trace] = try fixture("trajectories")
        XCTAssertEqual(campaign.levels.count, 12)
        XCTAssertEqual(campaign.worlds.count, 3)
        XCTAssertEqual(traces.count, 27)
        for trace in traces {
            let level = try XCTUnwrap(campaign.levels.first { $0.id == trace.level })
            let assignments = Dictionary(uniqueKeysWithValues: zip(level.walkers, trace.crossings).map { walker, crossing in
                (walker.id, Assignment(crossing: crossing, skills: Set(trace.skills[walker.id] ?? [])))
            })
            let plan = Plan(people: assignments, street: Set(trace.street))
            let sim = Simulation(level, plan)
            XCTAssertEqual(plan.cost(campaign.tools), trace.cost)
            for (old, sample) in zip([0] + trace.samples.map(\.frame), trace.samples) {
                for _ in old..<sample.frame { sim.tick() }
                let context = "Nivel \(trace.level), \(trace.name), fotograma \(sample.frame)"
                XCTAssertEqual(String(describing: sim.phase), sample.phase, context)
                XCTAssertEqual(sim.time, sample.time, accuracy: 0.0001, context)
                XCTAssertEqual(sim.people.map(\.done), sample.peopleDone, context)
                for (person, expected) in zip(sim.people, sample.peopleY) {
                    XCTAssertEqual(person.y, expected, accuracy: 0.0001, context)
                }
                for (index, lane) in level.lanes.enumerated() {
                    XCTAssertEqual(sim.carX(lane), sample.cars[index], accuracy: 0.0001, context)
                    XCTAssertEqual(sim.carSpeed(lane), sample.speeds[index], accuracy: 0.0001, context)
                    XCTAssertEqual(sim.isBraking(lane), sample.braking[index], context)
                    let ambush = sim.ambushCarsFor(lane)
                    let expected = sample.ambushCars[index]
                    XCTAssertEqual(ambush.count, expected.count, context)
                    for (car, values) in zip(ambush, expected) {
                        XCTAssertEqual(car.x, values[0], accuracy: 0.0001, context)
                        XCTAssertEqual(car.direction, values[1], context)
                    }
                }
                let oncomingLanes = level.lanes.filter(\.twoWay)
                for (lane, expected) in zip(oncomingLanes, sample.oncoming) {
                    XCTAssertEqual(sim.oncomingCarX(lane), expected, accuracy: 0.0001, context)
                }
            }
            XCTAssertEqual(sim.stars(plan.cost(campaign.tools)), trace.stars)
            XCTAssertEqual(sim.reason, trace.reason)
            XCTAssertEqual(sim.collapsedWalkerId, trace.collapsedWalker)
            XCTAssertEqual(sim.collapsedCarRole.map { String(describing: $0) }, trace.collapsedRole)
        }
    }

    private struct Trace: Decodable {
        let name: String
        let level: Int
        let crossings: [Int]
        let skills: [String: [String]]
        let street: [String]
        let cost: Int
        let stars: Int
        let reason: String
        let collapsedWalker: String?
        let collapsedRole: String?
        let samples: [Sample]
    }

    private struct Sample: Decodable {
        let frame: Int
        let time: Float
        let phase: String
        let peopleY: [Float]
        let peopleDone: [Bool]
        let cars: [Float]
        let speeds: [Float]
        let braking: [Bool]
        let oncoming: [Float]
        let ambushCars: [[[Float]]]
    }
}
