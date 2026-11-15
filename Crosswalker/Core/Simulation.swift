import Foundation

struct Lane: Codable, Hashable {
    let y: Float
    let speed: Float
    let offset: Float
    let car: String
    let twoWay: Bool
    let oncomingOffset: Float
    let blindSpot: Bool

    init(y: Float, speed: Float, offset: Float, car: String,
         twoWay: Bool = false, oncomingOffset: Float = 0.7, blindSpot: Bool = false) {
        self.y = y
        self.speed = speed
        self.offset = offset
        self.car = car
        self.twoWay = twoWay
        self.oncomingOffset = oncomingOffset
        self.blindSpot = blindSpot
    }

    private enum CodingKeys: String, CodingKey { case y, speed, offset, car, twoWay, oncomingOffset, blindSpot }

    init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            y: try data.decode(Float.self, forKey: .y),
            speed: try data.decode(Float.self, forKey: .speed),
            offset: try data.decode(Float.self, forKey: .offset),
            car: try data.decode(String.self, forKey: .car),
            twoWay: try data.decodeIfPresent(Bool.self, forKey: .twoWay) ?? false,
            oncomingOffset: try data.decodeIfPresent(Float.self, forKey: .oncomingOffset) ?? 0.7,
            blindSpot: try data.decodeIfPresent(Bool.self, forKey: .blindSpot) ?? false
        )
    }
}

struct Walker: Codable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let speed: Float
    let sprite: String
}

struct Level: Codable, Identifiable {
    let id: Int
    let world: Int
    let title: String
    let lesson: String
    let budget: Int
    let night: Bool
    let lanes: [Lane]
    let walkers: [Walker]
    let tools: [String]
    let newTools: [String]
    let tutorial: Bool
    let introLines: [String]
    let readyMessage: String
    let weather: String
    let sight: [Float]
    let accessible: [Int]
    let parCost: Int
    let blockedCrossing: Int?
    let guideTools: [String]
    let trafficYields: Bool
    let trafficPace: Float
    let pedestrianCrossings: [Int]
    let rainBrakingLesson: Bool
    let initialCrossings: [Int]

    init(id: Int, world: Int, title: String, lesson: String, budget: Int, night: Bool,
         lanes: [Lane], walkers: [Walker], tools: [String] = [], newTools: [String] = [],
         tutorial: Bool = false, introLines: [String] = [], readyMessage: String = "",
         weather: String = "dry", sight: [Float] = [0.95, 0.95, 0.95],
         accessible: [Int] = [1], parCost: Int = 0, blockedCrossing: Int? = nil,
         guideTools: [String] = [], trafficYields: Bool = true, trafficPace: Float = 1,
         pedestrianCrossings: [Int] = [], rainBrakingLesson: Bool = false, initialCrossings: [Int] = []) {
        self.id = id
        self.world = world
        self.title = title
        self.lesson = lesson
        self.budget = budget
        self.night = night
        self.lanes = lanes
        self.walkers = walkers
        self.tools = tools
        self.newTools = newTools
        self.tutorial = tutorial
        self.introLines = introLines
        self.readyMessage = readyMessage
        self.weather = weather
        self.sight = sight
        self.accessible = accessible
        self.parCost = parCost
        self.blockedCrossing = blockedCrossing
        self.guideTools = guideTools
        self.trafficYields = trafficYields
        self.trafficPace = trafficPace
        self.pedestrianCrossings = pedestrianCrossings
        self.rainBrakingLesson = rainBrakingLesson
        self.initialCrossings = initialCrossings
    }

    private enum CodingKeys: String, CodingKey {
        case id, world, title, lesson, budget, night, lanes, walkers, tools, newTools
        case tutorial, introLines, readyMessage, weather, sight, accessible, parCost, blockedCrossing
        case guideTools, trafficYields, trafficPace, pedestrianCrossings, rainBrakingLesson, initialCrossings
    }

    init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        let id = try data.decode(Int.self, forKey: .id)
        let walkers = try data.decode([Walker].self, forKey: .walkers)
        let blockedCrossing = try data.decodeIfPresent(Int.self, forKey: .blockedCrossing)
        let initialCrossings = try data.decodeIfPresent([Int].self, forKey: .initialCrossings)
        if let crossings = initialCrossings {
            guard crossings.count == walkers.count, Set(crossings).count == crossings.count,
                  crossings.allSatisfy({ Simulation.crossings.indices.contains($0) && $0 != blockedCrossing }) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .initialCrossings, in: data,
                    debugDescription: "Nivel \(id): los cruces iniciales deben ser distintos y estar abiertos."
                )
            }
        }
        // Decode to Double first, as Android's campaign reader does before converting to Float.
        let sight = try data.decodeIfPresent([Double].self, forKey: .sight)?.map { Float($0) } ?? [0.95, 0.95, 0.95]
        self.init(
            id: id,
            world: try data.decode(Int.self, forKey: .world),
            title: try data.decode(String.self, forKey: .title),
            lesson: try data.decode(String.self, forKey: .lesson),
            budget: try data.decode(Int.self, forKey: .budget),
            night: try data.decode(Bool.self, forKey: .night),
            lanes: try data.decode([Lane].self, forKey: .lanes),
            walkers: walkers,
            tools: try data.decodeIfPresent([String].self, forKey: .tools) ?? [],
            newTools: try data.decodeIfPresent([String].self, forKey: .newTools) ?? [],
            tutorial: try data.decodeIfPresent(Bool.self, forKey: .tutorial) ?? false,
            introLines: try data.decodeIfPresent([String].self, forKey: .introLines) ?? [],
            readyMessage: try data.decodeIfPresent(String.self, forKey: .readyMessage) ?? "",
            weather: try data.decodeIfPresent(String.self, forKey: .weather) ?? "dry",
            sight: sight,
            accessible: try data.decodeIfPresent([Int].self, forKey: .accessible) ?? [1],
            parCost: try data.decodeIfPresent(Int.self, forKey: .parCost) ?? 0,
            blockedCrossing: blockedCrossing,
            guideTools: try data.decodeIfPresent([String].self, forKey: .guideTools) ?? [],
            trafficYields: try data.decodeIfPresent(Bool.self, forKey: .trafficYields) ?? true,
            trafficPace: try data.decodeIfPresent(Float.self, forKey: .trafficPace) ?? 1,
            pedestrianCrossings: try data.decodeIfPresent([Int].self, forKey: .pedestrianCrossings) ?? [],
            rainBrakingLesson: try data.decodeIfPresent(Bool.self, forKey: .rainBrakingLesson) ?? false,
            initialCrossings: initialCrossings ?? []
        )
    }

    func hasMarkedCrossing(_ crossing: Int) -> Bool { pedestrianCrossings.contains(crossing) }
    func showsChildBadge(_ walker: Walker) -> Bool { tools.contains("escort") && walker.kind == "impulsive" }
}

struct Tool: Codable, Identifiable {
    let id: String
    let label: String
    let icon: String
    let cost: Int
    let description: String
    let category: String

    func explanation(_ level: Level) -> String {
        if id == "look" && !level.tutorial {
            return "Comprueba todos los carriles y espera un hueco para completar el tramo. No sirve mientras miras el celular ni si la vista está bloqueada."
        }
        return description
    }
}

struct Campaign: Codable { let worlds: [String]; let tools: [Tool]; let levels: [Level] }
struct Assignment { var crossing = 1; var skills: Set<String> = [] }
struct Plan {
    var people: [String: Assignment] = [:]
    var street: Set<String> = []

    mutating func moveWalker(_ walkerId: String, crossing: Int) {
        guard let assignment = people[walkerId] else { return }
        if let occupied = people.first(where: { $0.key != walkerId && $0.value.crossing == crossing })?.key {
            people[occupied]?.crossing = assignment.crossing
        }
        people[walkerId]?.crossing = crossing
    }

    func cost(_ tools: [Tool]) -> Int {
        tools.reduce(0) { total, tool in
            let count = tool.category == "street"
                ? (street.contains(tool.id) ? 1 : 0)
                : people.values.filter { $0.skills.contains(tool.id) }.count
            return total + tool.cost * count
        }
    }
}

enum Phase: Equatable { case planning, running, won, retry }
enum HitCarRole: Equatable { case main, oncoming, ambush }

struct PersonState {
    let walker: Walker
    let x: Float
    var y: Float = 0.91
    var done = false
}

final class Simulation {
    static let step: Float = 0.05
    static let crossings: [Float] = [0.25, 0.5, 0.75]
    static let defaultRecklessSpeed: Float = 1.08

    let level: Level
    let plan: Plan
    private(set) var phase: Phase = .running
    private(set) var time: Float = 0
    private(set) var reason = ""
    private(set) var collapsedWalkerId: String?
    private(set) var collapsedLane: Lane?
    private(set) var collapsedCarRole: HitCarRole?
    private(set) var collapsedCarX: Float?
    private(set) var impactSpeed: Float = 0
    private(set) var feedback = ""
    private(set) var people: [PersonState]

    private final class Vehicle {
        var x: Float
        var speed: Float
        var reaction: Float = 0
        var braking = false
        var overrideSpeed: Float?
        var overrideUntil: Float = 0

        init(x: Float, speed: Float) {
            self.x = x
            self.speed = speed
        }
    }

    private struct AmbushCar {
        let lane: Lane
        var x: Float
        var previousX: Float
        let direction: Float
        let speed: Float
        let until: Float
        let walkerId: String
    }

    private struct Trigger: Hashable {
        let walkerId: String
        let laneY: Float
    }

    private let recklessSpeed: Float
    private let trafficLoopLength: Float
    private let trafficLoopStart: Float
    private let headlightsOn: Bool
    private let carefulNightTraffic: Bool
    private let fastTrafficInRain: Bool
    private var trafficClocks: [Lane: Float]
    private let vehicles: [Lane: Vehicle]
    private let oncoming: [Lane: Vehicle]
    private var recklessTriggered: Set<Trigger> = []
    private var ambushCars: [AmbushCar] = []
    private var waitingReasons: [String: String] = [:]

    init(_ level: Level, _ source: Plan, recklessSpeed: Float = Simulation.defaultRecklessSpeed) {
        self.level = level
        plan = source
        self.recklessSpeed = recklessSpeed
        let length: Float = 1.4 * level.trafficPace
        trafficLoopLength = length
        trafficLoopStart = (1 - length) / 2
        let lit = level.night && source.street.contains("car_lights")
        headlightsOn = lit
        carefulNightTraffic = lit && source.street.contains("speed_zone")
        fastTrafficInRain = level.rainBrakingLesson && level.weather == "rain" && !source.street.contains("speed_zone")
        people = level.walkers.map {
            let crossing = source.people[$0.id]?.crossing ?? 1
            let x = Self.crossings.indices.contains(crossing) ? Self.crossings[crossing] : Self.crossings[1]
            return PersonState(walker: $0, x: x)
        }
        let factor: Float = source.street.contains("speed_zone") && !level.tutorial ? 0.55 : 1
        trafficClocks = Dictionary(level.lanes.map { ($0, Float(0)) }, uniquingKeysWith: { _, new in new })
        vehicles = Dictionary(level.lanes.map { lane in
            (lane, Vehicle(x: lane.offset - 0.2, speed: abs(lane.speed) * level.trafficPace * factor))
        }, uniquingKeysWith: { _, new in new })
        oncoming = Dictionary(level.lanes.filter(\.twoWay).map { lane in
            (lane, Vehicle(x: lane.oncomingOffset - 0.2, speed: abs(lane.speed) * level.trafficPace * factor * recklessSpeed))
        }, uniquingKeysWith: { _, new in new })
    }

    private func baseSpeed(_ lane: Lane) -> Float {
        abs(lane.speed) * level.trafficPace * (plan.street.contains("speed_zone") && !level.tutorial ? 0.55 : 1)
    }

    private func direction(_ lane: Lane) -> Float { lane.speed >= 0 ? 1 : -1 }

    private func positiveRemainder(_ value: Float, divisor: Float) -> Float {
        (value.truncatingRemainder(dividingBy: divisor) + divisor).truncatingRemainder(dividingBy: divisor)
    }

    private func wrap(_ x: Float) -> Float {
        positiveRemainder(x - trafficLoopStart, divisor: trafficLoopLength) + trafficLoopStart
    }

    private func carsFor(_ lane: Lane) -> [(car: Vehicle, direction: Float, oncoming: Bool)] {
        var cars = [(vehicles[lane]!, direction(lane), false)]
        if let car = oncoming[lane] { cars.append((car, -direction(lane), true)) }
        return cars
    }

    private func laneAlreadyThreatens(_ lane: Lane, _ person: PersonState) -> Bool {
        let duration = (person.y - lane.y + 0.07) / pace(person)
        let arrival = max(0, (person.y - lane.y - 0.07) / pace(person))
        return carsFor(lane).contains { car, direction, _ in
            (0...40).contains { sample in
                let t = arrival + (duration - arrival) * Float(sample) / 40
                return abs(wrap(car.x + direction * car.speed * t) - person.x) < 0.12
            }
        }
    }

    func carSpeed(_ lane: Lane) -> Float { level.tutorial ? abs(lane.speed) : vehicles[lane]!.speed }
    func isBraking(_ lane: Lane) -> Bool { !level.tutorial && vehicles[lane]!.braking }
    func oncomingCarX(_ lane: Lane) -> Float { oncoming[lane]!.x }
    func ambushCarsFor(_ lane: Lane) -> [(x: Float, direction: Float)] {
        ambushCars.filter { $0.lane == lane }.map { ($0.x, $0.direction) }
    }

    func carX(_ lane: Lane, ahead: Float = 0) -> Float {
        if !level.tutorial {
            let car = vehicles[lane]!
            return wrap(car.x + direction(lane) * car.speed * ahead)
        }
        let school: Float = plan.street.contains("school") ? 0.7 : 1
        let bump: Float = plan.street.contains("bump") ? 0.65 : 1
        let multiplier = school * bump
        let t = trafficClocks[lane]! + ahead
        return positiveRemainder(lane.offset + lane.speed * multiplier * t, divisor: 1.4) - 0.2
    }

    func tick(_ dt: Float = Simulation.step) {
        guard phase == .running else { return }
        precondition(dt > 0 && dt.isFinite)
        if time == 0 && Set(people.map(crossing)).count != people.count {
            reject("Asigna un cruce diferente a cada peatón.")
            return
        }
        if !level.tutorial {
            var remaining = dt
            while remaining > 0.000001 && phase == .running {
                let step = min(remaining, 0.02)
                tickTraffic(step)
                remaining -= step
            }
            return
        }

        time += dt
        let officer = plan.street.contains("officer") && time < 6
        if !officer {
            for lane in level.lanes {
                let yield = people.contains { person in
                    let actions = skills(person)
                    let visible = actions.contains(level.night ? "visible" : "eye")
                    let distance = (person.x - carX(lane)) * (lane.speed > 0 ? 1 : -1)
                    return visible && !person.done && person.y > lane.y - 0.09
                        && person.y < lane.y + 0.22 && (0.10...0.25).contains(distance)
                }
                if !yield { trafficClocks[lane, default: 0] += dt }
            }
        }

        for index in people.indices {
            var person = people[index]
            if person.done { continue }
            let skills = self.skills(person)
            if skills.contains("wait") && time < 3 { continue }
            var velocity = person.walker.speed * (plan.street.contains("crosswalk") ? 1.2 : 1)
            if person.walker.kind == "distracted" && !skills.contains("look") { velocity *= 0.75 }
            if person.walker.kind == "wheelchair" && !plan.street.contains("crosswalk") { velocity *= 0.5 }
            if person.walker.kind == "phone" && !skills.contains("phone_away") { velocity *= 0.5 }
            let yielding = (skills.contains("eye") && !level.night) || (skills.contains("visible") && level.night)
            let looking = skills.contains("look") && !yielding
                && (person.walker.kind != "phone" || skills.contains("phone_away"))
            if let lane = level.lanes.first(where: { person.y > $0.y + 0.065 && person.y - $0.y < 0.15 }), looking {
                let duration = (person.y - lane.y + 0.075) / velocity
                let hazard = (0...30).contains { sample in
                    abs(carX(lane, ahead: duration * Float(sample) / 30) - person.x) < 0.135
                }
                if hazard && !officer { continue }
            }
            person.y -= velocity * dt
            people[index] = person
            for lane in level.lanes {
                let near = abs(person.y - lane.y) < 0.066 && abs(person.x - carX(lane)) < 0.115
                if near && !yielding && !officer {
                    collapsedWalkerId = person.walker.id
                    collapsedLane = lane
                    collapsedCarRole = .main
                    collapsedCarX = carX(lane)
                    reject(collisionReason(person, lane, role: .main, staged: false))
                    return
                }
            }
            if person.y <= 0.08 { people[index].done = true }
        }

        if people.allSatisfy(\.done) { phase = .won }
        if time > 90 && phase == .running { reject("Probemos otro plan para encontrar un momento seguro.") }
    }

    private func crossing(_ person: PersonState) -> Int { plan.people[person.walker.id]?.crossing ?? 1 }
    private func skills(_ person: PersonState) -> Set<String> { plan.people[person.walker.id]?.skills ?? [] }
    private func focused(_ person: PersonState) -> Bool {
        person.walker.kind != "phone" || skills(person).contains("phone_away")
    }

    private func outsideNightCrossing(_ person: PersonState) -> Bool {
        level.night && !level.pedestrianCrossings.isEmpty && !level.hasMarkedCrossing(crossing(person))
    }

    private func checksTraffic(_ person: PersonState) -> Bool {
        focused(person) && !outsideNightCrossing(person) && (skills(person).contains("look") || carefulNightTraffic)
    }

    private func sight(_ person: PersonState) -> Float {
        let base = level.sight[crossing(person)]
        let light: Float
        if !level.night || (plan.street.contains("lighting") && crossing(person) == 1) {
            light = 1
        } else if headlightsOn {
            light = 0.9
        } else if skills(person).contains("visible") {
            light = 0.75
        } else {
            light = 0.55
        }
        let impulsive: Float = person.walker.kind == "impulsive" && !skills(person).contains("escort") ? 0.8 : 1
        let headlights: Float = level.night && !headlightsOn ? 0.7 : 1
        let fog: Float = level.weather == "fog" ? 0.7 : 1
        return base * light * impulsive * headlights * fog
    }

    private func perceivedRange(_ person: PersonState) -> Float {
        let wearingHeadphones = person.walker.kind == "headphones" && !skills(person).contains("headphones_off")
        return sight(person) * (wearingHeadphones ? 0.5 : 1)
    }

    func sightRange(walkerId: String) -> Float {
        people.first { $0.walker.id == walkerId }.map(perceivedRange) ?? 1
    }

    private func pace(_ person: PersonState) -> Float {
        person.walker.speed * (level.weather == "rain" ? 0.85 : 1) * (!focused(person) ? 0.65 : 1)
    }

    private func stopDistance(_ speed: Float) -> Float { speed * 0.65 + speed * speed / (2 * deceleration()) }
    private func deceleration() -> Float { level.weather == "rain" ? 0.055 : 0.12 }

    private func reject(_ message: String) {
        phase = .retry
        reason = message
    }

    private func stepVehicle(_ lane: Lane, car: Vehicle, direction: Float, dt: Float, reckless: Bool = false) {
        if let speed = car.overrideSpeed {
            car.braking = false
            car.reaction = 0
            car.speed = speed
            car.x = wrap(car.x + direction * speed * dt)
            return
        }

        let nominal = baseSpeed(lane) * (reckless ? recklessSpeed : 1)
        if reckless || (!level.trafficYields && !fastTrafficInRain) {
            car.braking = false
            car.reaction = 0
            car.speed = min(nominal, car.speed + 0.08 * dt)
            car.x = wrap(car.x + direction * car.speed * dt)
            return
        }

        let targets = people.filter { person in
            let distance = (person.x - car.x) * direction
            let unlit = level.night && !headlightsOn && !skills(person).contains("visible")
            let detection = sight(person) * (unlit ? 0.45 : 1) * (lane.blindSpot ? 0.5 : 1)
            let atRoad = person.y > lane.y - 0.09 && person.y <= 0.94
            let marked: Bool
            if level.night && !level.pedestrianCrossings.isEmpty {
                marked = level.hasMarkedCrossing(crossing(person))
            } else {
                marked = (plan.street.contains("crosswalk") && level.accessible.contains(crossing(person))) || headlightsOn
            }
            let seesPedestrian = fastTrafficInRain
                ? person.y <= lane.y + 0.10 && distance < min(detection, 0.23)
                : marked && distance < detection
            return !person.done && atRoad && distance > 0.10 && seesPedestrian
        }
        let target = targets.min { ($0.x - car.x) * direction < ($1.x - car.x) * direction }
        let request = target.map { ($0.x - car.x) * direction - 0.12 <= stopDistance(car.speed) + 0.35 } ?? false
        car.reaction = request ? car.reaction + dt : 0
        car.braking = request && car.reaction >= 0.35
        car.speed = car.braking ? max(0, car.speed - deceleration() * dt) : min(nominal, car.speed + 0.08 * dt)
        car.x = wrap(car.x + direction * car.speed * dt)
    }

    private func collisionReason(_ person: PersonState, _ lane: Lane, role: HitCarRole, staged: Bool) -> String {
        let vehicle = role == .oncoming ? "un coche que venía en sentido contrario" : (lane.blindSpot ? "un vehículo grande" : "un coche")
        if outsideNightCrossing(person) {
            return "\(person.walker.name) cruzó fuera del paso peatonal y chocó con \(vehicle). "
                + "De noche, usa un cruce con franjas blancas. Ahí los conductores esperan peatones."
        }
        let action: String
        if !focused(person) && level.tools.contains("phone_away") {
            action = "Asígnale Guardar celular en Habilidades."
        } else if level.night && !headlightsOn && level.tools.contains("car_lights") {
            action = "Activa Encender luces para mejorar la visibilidad."
        } else if level.night && level.tools.contains("speed_zone") && !plan.street.contains("speed_zone") {
            action = "Activa Bajar velocidad para dar a los conductores más tiempo de reacción."
        } else if fastTrafficInRain {
            action = "Con lluvia, los coches necesitan más distancia para frenar. Activa Bajar velocidad en La calle."
        } else if !checksTraffic(person) && level.tools.contains("look") {
            action = "Asígnale Mirar para que espere un hueco."
        } else if level.weather == "rain" {
            action = "Con lluvia aumenta la distancia de frenado. Prueba otro cruce o deja más margen."
        } else {
            action = "Prueba otro cruce para que tenga más margen."
        }
        let event = staged && !checksTraffic(person)
            ? "\(person.walker.name) entró al carril sin comprobar el tráfico y chocó con \(vehicle)."
            : "\(person.walker.name) chocó con \(vehicle) mientras cruzaba."
        return "\(event) \(action)"
    }

    private func invalidPlanReason() -> String? {
        let available = Set(level.tools)
        let used = plan.street.union(plan.people.values.flatMap(\.skills))
        if !used.isSubset(of: available) { return "Esa ficha no está disponible en este camino." }
        if plan.people.values.contains(where: { !(0...2).contains($0.crossing) }) {
            return "Elige uno de los tres cruces."
        }
        if let blocked = level.blockedCrossing, plan.people.values.contains(where: { $0.crossing == blocked }) {
            return "Ese cruce está bloqueado por una obra. Elige otro camino."
        }
        if let rider = people.first(where: {
            $0.walker.kind == "wheelchair" && !(plan.street.contains("crosswalk") && level.accessible.contains(crossing($0)))
        }) {
            return "\(rider.walker.name) necesita una rampa. Usa la ficha Rampa y elige uno de los cruces indicados."
        }
        let distracted = people.filter { !focused($0) }
        if !distracted.isEmpty && available.contains("phone_away") {
            return distracted.map {
                "\($0.walker.name) sigue mirando el celular. Asígnale Guardar celular en Habilidades."
            }.joined(separator: " ")
        }
        return nil
    }

    private func clearToCross(_ person: PersonState, lanesAhead: [Lane]) -> (room: Bool, limitedVisibility: Bool) {
        var limitedVisibility = false
        let move = lanesAhead.allSatisfy { lane in
            let duration = (person.y - lane.y + 0.07) / pace(person)
            let arrival = max(0, (person.y - lane.y - 0.07) / pace(person))
            return carsFor(lane).allSatisfy { car, direction, isOncoming in
                let nominal = baseSpeed(lane) * (isOncoming ? recklessSpeed : 1)
                // Only a car stopped before the crossing is safe to pass in front of.
                let stopped = !isOncoming && car.speed < 0.002 && (person.x - car.x) * direction > 0.115
                let horizon = nominal * duration / level.trafficPace
                if !stopped && horizon > perceivedRange(person) {
                    limitedVisibility = true
                    return false
                }
                return !(0...40).contains { sample in
                    let t = arrival + (duration - arrival) * Float(sample) / 40
                    let x = wrap(car.x + direction * max(car.speed, nominal) * t)
                    return !stopped && abs(x - person.x) < 0.12
                }
            }
        }
        return (move, limitedVisibility)
    }

    private func waitingHelp(_ person: PersonState, limitedVisibility: Bool) -> String {
        if !limitedVisibility { return "no encontró un hueco suficiente. Prueba otro cruce." }
        if person.walker.kind == "headphones" && !skills(person).contains("headphones_off") && level.tools.contains("headphones_off") {
            return "no tenía margen para comprobar el tráfico con los audífonos puestos. Asígnale Quitar audífonos."
        }
        if level.night && !headlightsOn && level.tools.contains("car_lights") {
            return "no alcanzó a ver el tráfico desde su cruce. Activa Encender luces."
        }
        if level.tools.contains("speed_zone") && !plan.street.contains("speed_zone") {
            return "necesita más margen para cruzar. Prueba Bajar velocidad u otro cruce."
        }
        return "no tuvo visibilidad suficiente para completar el cruce. Revisa su cruce y las mejoras disponibles."
    }

    private func stageSurpriseCars(for person: PersonState) {
        for lane in level.lanes {
            let key = Trigger(walkerId: person.walker.id, laneY: lane.y)
            if recklessTriggered.contains(key) || !(lane.y - 0.02...lane.y + 0.14).contains(person.y) { continue }
            recklessTriggered.insert(key)
            if laneAlreadyThreatens(lane, person) { continue }
            let dir: Float
            switch crossing(person) {
            case 0: dir = 1
            case 2: dir = -1
            default: dir = lane.twoWay ? -direction(lane) : direction(lane)
            }

            let edge: Float = dir > 0 ? -0.2 : 1.2
            let timeToCenter = max(0.25, (person.y - lane.y) / pace(person))
            let speed = abs(person.x - edge) / timeToCenter
            let until = time + timeToCenter + 0.4
            let reuse = dir == direction(lane) ? vehicles[lane] : oncoming[lane]
            if let reuse = reuse, people.count == 1 {
                reuse.x = edge
                reuse.overrideSpeed = speed
                reuse.overrideUntil = until
            } else {
                ambushCars.append(AmbushCar(
                    lane: lane, x: edge, previousX: edge, direction: dir, speed: speed, until: until, walkerId: person.walker.id
                ))
            }
        }
    }

    private func registerHit(_ person: PersonState, lane: Lane, role: HitCarRole, x: Float, speed: Float, staged: Bool) {
        impactSpeed = speed
        collapsedWalkerId = person.walker.id
        collapsedLane = lane
        collapsedCarRole = role
        collapsedCarX = x
        reject(collisionReason(person, lane, role: role, staged: staged))
    }

    private func tickTraffic(_ dt: Float) {
        if time == 0, let message = invalidPlanReason() {
            reject(message)
            return
        }
        time += dt
        let previous = vehicles.mapValues(\.x)
        let previousOncoming = oncoming.mapValues(\.x)
        for lane in level.lanes {
            stepVehicle(lane, car: vehicles[lane]!, direction: direction(lane), dt: dt)
        }
        for lane in level.lanes where lane.twoWay {
            stepVehicle(lane, car: oncoming[lane]!, direction: -direction(lane), dt: dt, reckless: true)
        }
        for index in ambushCars.indices {
            let car = ambushCars[index]
            ambushCars[index].previousX = car.x
            ambushCars[index].x = wrap(car.x + car.direction * car.speed * dt)
        }

        let curb = (level.lanes.map(\.y).max() ?? 0) + 0.12
        for index in people.indices {
            var person = people[index]
            if person.done { continue }
            waitingReasons.removeValue(forKey: person.walker.id)
            let checking = checksTraffic(person)
            var move = true
            if person.y >= curb && checking {
                let lanesAhead = level.lanes.filter { $0.y < person.y - 0.05 }
                if fastTrafficInRain {
                    if let latest = lanesAhead.max(by: { $0.y < $1.y }) {
                        move = !carsFor(latest).contains { abs($0.car.x - person.x) < 0.12 }
                    }
                } else {
                    let clearance = clearToCross(person, lanesAhead: lanesAhead)
                    move = clearance.room
                    if !move {
                        let help = waitingHelp(person, limitedVisibility: clearance.limitedVisibility)
                        waitingReasons[person.walker.id] = "\(person.walker.name) se quedó esperando: \(help)"
                    }
                }
            }

            let oldY = person.y
            if move { person.y -= pace(person) * dt }
            people[index] = person
            if !checking { stageSurpriseCars(for: person) }
            for lane in level.lanes {
                var hits: [(Vehicle, Float, HitCarRole)] = [(vehicles[lane]!, previous[lane]!, .main)]
                if let car = oncoming[lane] { hits.append((car, previousOncoming[lane]!, .oncoming)) }
                for (car, oldX, role) in hits {
                    if abs(car.x - oldX) < 0.7 && sweptHit(oldX, car.x, oldY, person.y, person.x, lane.y) {
                        registerHit(person, lane: lane, role: role, x: car.x, speed: car.speed, staged: car.overrideSpeed != nil)
                        return
                    }
                }
                for car in ambushCars where car.lane == lane && car.walkerId == person.walker.id {
                    if abs(car.x - car.previousX) < 0.7 && sweptHit(car.previousX, car.x, oldY, person.y, person.x, lane.y) {
                        registerHit(person, lane: lane, role: .ambush, x: car.x, speed: car.speed, staged: true)
                        return
                    }
                }
            }
            if person.y <= 0.08 { people[index].done = true }
        }

        ambushCars.removeAll { time > $0.until }
        for car in Array(vehicles.values) + Array(oncoming.values) where car.overrideSpeed != nil && time > car.overrideUntil {
            car.overrideSpeed = nil
        }
        feedback = people.lazy.compactMap { self.waitingReasons[$0.walker.id] }.first ?? ""
        if people.allSatisfy(\.done) {
            phase = .won
            feedback = "¡Todos llegaron con un plan seguro!"
        }
        if time >= 90 && phase == .running {
            let pending = people.filter { !$0.done }
            reject(pending.map { person in
                waitingReasons[person.walker.id]
                    ?? "\(person.walker.name) no terminó de cruzar antes de que se acabara el tiempo."
            }.joined(separator: " "))
        }
    }

    private func sweptHit(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ px: Float, _ ly: Float) -> Bool {
        func interval(_ a: Float, _ b: Float, center: Float, radius: Float) -> (Float, Float) {
            if abs(b - a) < 0.000001 { return abs(a - center) < radius ? (0, 1) : (2, -1) }
            let t0 = (center - radius - a) / (b - a)
            let t1 = (center + radius - a) / (b - a)
            return (min(t0, t1), max(t0, t1))
        }
        let x = interval(x0, x1, center: px, radius: 0.115)
        let y = interval(y0, y1, center: ly, radius: 0.065)
        return max(0, x.0, y.0) < min(1, x.1, y.1)
    }

    func stars(_ cost: Int) -> Int {
        guard phase == .won else { return 0 }
        let threshold = level.parCost > 0 && !level.tutorial ? Float(level.parCost) : Float(level.budget) * 0.65
        return Float(cost) <= threshold ? 3 : 2
    }
}
