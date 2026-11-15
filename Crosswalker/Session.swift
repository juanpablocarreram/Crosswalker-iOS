import AVFoundation
import SwiftUI

enum Screen: Equatable { case home, map, game, credits }
enum ScreenMotion: Equatable {
    case forward, backward, fade
    var backwards: Bool { self == .backward }
}

@MainActor final class Session: ObservableObject {
    let repo: GameRepository
    @Published var screen: Screen = .home
    @Published var world = 0
    @Published var level: Level
    @Published var plan = Plan()
    @Published var selected = ""
    @Published var simulation: Simulation?
    @Published var frame = 0
    @Published var paused = false
    @Published var dialog = ""
    @Published var chosen: Level?
    @Published var tab = "skill"
    @Published var introIndex = 0
    @Published var planningPanelOpen = false
    @Published var showResult = false
    @Published var transitioning = false
    @Published var sound: Bool { didSet { repo.sound = sound; refreshAudio(restart: true) } }
    @Published var guidance: Bool { didSet { repo.guidance = guidance } }
    var transition: (ScreenMotion, @escaping () -> Void) -> Void = { _, action in action() }

    private var active = true
    private var resultTask: Task<Void, Never>?
    private var music: AVAudioPlayer?
    private var musicName: String?
    private var effects: [String: AVAudioPlayer] = [:]
    private var ambient: AVAudioPlayer?
    private var voice: AVAudioPlayer?

    init(repo: GameRepository) {
        self.repo = repo
        level = repo.levels[0]
        sound = repo.sound
        guidance = repo.guidance
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        reset()
    }

    var cost: Int { plan.cost(repo.tools) }
    var remaining: Int { level.budget - cost }
    var totalStars: Int { repo.levels.reduce(0) { $0 + repo.stars($1.id) } }
    var completed: Int { repo.levels.filter { repo.stars($0.id) > 0 }.count }
    var walker: Walker { level.walkers.first { $0.id == selected } ?? level.walkers[0] }
    var skills: Set<String> { plan.people[selected]?.skills ?? [] }
    var tutorialActive: Bool { level.tutorial && !repo.tutorialDone && simulation == nil }
    var guideTool: Tool? {
        guard !level.tutorial, level.guideTools.indices.contains(introIndex) else { return nil }
        return repo.tools.first { $0.id == level.guideTools[introIndex] }
    }

    var tutorialTarget: (spotlight: String, tap: String)? {
        guard tutorialActive else { return nil }
        if !planningPanelOpen {
            return introIndex == 2 ? ("board", "planning_panel") : ("planning_panel", "planning_panel")
        }
        if introIndex < level.introLines.count - 1 {
            switch introIndex {
            case 0...3: return ("dialogue", "dialogue")
            case 4: return ("pause", "dialogue")
            case 5: return ("tokens", "dialogue")
            case 6: return ("walkers", "dialogue")
            case 7: return ("tab_skill", "dialogue")
            case 8: return ("tab_street", "dialogue")
            default: return ("crossing", "dialogue")
            }
        }
        if introIndex == level.introLines.count - 1 { return ("crossing", "crossing") }
        return skills.contains("look") ? ("launch", "launch") : ("tool_look", "tool_look")
    }

    func permits(_ target: String) -> Bool { tutorialTarget.map { $0.tap == target } ?? true }

    var guideMessage: String {
        if tutorialActive && !planningPanelOpen && introIndex != 2 {
            return "Toca la pestaña con la mano para abrir el plan. Vuelve a tocarla cuando quieras cerrar el panel."
        }
        if level.introLines.indices.contains(introIndex) { return level.introLines[introIndex] }
        if tutorialActive && skills.contains("look") { return level.readyMessage }
        return level.lesson
    }

    func advanceDialogue() {
        guard permits("dialogue"), introIndex < level.introLines.count - 1 else { return }
        introIndex += 1
        if tutorialActive && introIndex == 2 { planningPanelOpen = false }
    }

    func togglePanel() {
        guard permits("planning_panel") else { return }
        planningPanelOpen.toggle()
        if planningPanelOpen && tutorialActive && introIndex == 2 { introIndex += 1 }
        beep()
    }

    func navigate(_ destination: Screen) {
        guard destination != screen, !transitioning else { return }
        let returningFromCredits = screen == .credits && destination == .home
        let motion: ScreenMotion = destination == .credits || returningFromCredits ? .fade :
            (destination == .home || (screen == .game && destination == .map) ? .backward : .forward)
        transition(motion) {
            self.dialog = ""
            self.chosen = nil
            if self.screen == .game {
                self.resultTask?.cancel()
                self.simulation = nil
                self.showResult = false
                self.paused = false
                self.world = self.level.world
            }
            self.stopEffects()
            self.screen = destination
            if returningFromCredits { self.dialog = "campaignComplete" }
            self.refreshAudio()
        }
    }

    func changeWorld(_ next: Int) {
        guard next != world, !transitioning, repo.worlds.indices.contains(next) else { return }
        world = next
    }

    func enter(_ next: Level) {
        guard !transitioning, repo.unlocked(next.id) else { return }
        transition(.forward) {
            self.level = next
            self.screen = .game
            self.reset()
            self.playEffect("sfx_enter_level")
        }
    }

    func resumePlanning() {
        resultTask?.cancel()
        stopEffects()
        simulation = nil
        showResult = false
        planningPanelOpen = false
        refreshAudio(restart: true)
    }

    func reset() {
        resumePlanning()
        var available = [1, 0, 2].filter { $0 != level.blockedCrossing }
        var next = Plan()
        if level.initialCrossings.count == level.walkers.count {
            for (walker, crossing) in zip(level.walkers, level.initialCrossings) {
                next.people[walker.id] = Assignment(crossing: crossing)
            }
        } else {
            let sorted = level.walkers.filter { $0.kind == "wheelchair" } + level.walkers.filter { $0.kind != "wheelchair" }
            for walker in sorted {
                guard let first = available.first else { break }
                let crossing = walker.kind == "wheelchair" ? (available.first { level.accessible.contains($0) } ?? first) : first
                next.people[walker.id] = Assignment(crossing: crossing)
                available.removeAll { $0 == crossing }
            }
        }
        plan = next
        selected = level.walkers.first?.id ?? ""
        tab = "skill"
        paused = false
        dialog = ""
        introIndex = 0
        frame += 1
    }

    func resetProgress() {
        repo.resetProgress()
        world = 0
        level = repo.levels[0]
        reset()
        dialog = "progressReset"
    }

    func selectWalker(_ id: String) {
        guard permits("walkers"), selected != id, plan.people[id] != nil else { return }
        selected = id
        tab = "skill"
        beep()
    }

    func crossing(_ value: Int, fromBoard: Bool = true) {
        guard simulation == nil, Simulation.crossings.indices.contains(value), value != level.blockedCrossing else { return }
        guard permits(fromBoard ? "board" : "crossing") else { return }
        plan.moveWalker(selected, crossing: value)
        if tutorialActive { introIndex += 1 }
    }

    func toggle(_ tool: Tool) {
        guard simulation == nil, level.tools.contains(tool.id), permits("tool_" + tool.id) else { return }
        var next = plan
        if tool.category == "street" {
            if !next.street.insert(tool.id).inserted { next.street.remove(tool.id) }
        } else {
            guard var assignment = next.people[selected] else { return }
            if !assignment.skills.insert(tool.id).inserted { assignment.skills.remove(tool.id) }
            next.people[selected] = assignment
        }
        guard next.cost(repo.tools) <= level.budget else { dialog = "budget"; return }
        plan = next
    }

    func launch() {
        guard simulation == nil, permits("launch") else { return }
        beep()
        if tutorialActive { repo.tutorialDone = true }
        setDialogueVoice(false)
        simulation = Simulation(level, plan)
    }

    func tick() {
        guard active, !paused, !transitioning, let sim = simulation, sim.phase == .running else { return }
        sim.tick()
        frame += 1
        guard sim.phase == .won || sim.phase == .retry else { return }
        if sim.phase == .won {
            repo.save(sim.level.id, stars: sim.stars(sim.plan.cost(repo.tools)))
            beep(acknowledge: true)
        } else if sim.collapsedWalkerId != nil {
            playEffect("sfx_collapse")
        }
        refreshAudio()
        playEffect(sim.phase == .won ? "music_win" : "music_gameover")
        resultTask?.cancel()
        resultTask = Task { [weak self, weak sim] in
            do { try await Task.sleep(nanoseconds: 900_000_000) } catch { return }
            guard let self, let sim, self.simulation === sim else { return }
            if sim.phase == .won && self.repo.levels.last?.id == sim.level.id {
                self.navigate(.credits)
            } else {
                self.showResult = true
            }
        }
    }

    func setActive(_ value: Bool) {
        active = value
        if !value {
            if simulation?.phase == .running { paused = true }
            stopEffects()
        }
        refreshAudio()
    }

    func beep(acknowledge: Bool = false) { playEffect(acknowledge ? "ack" : "sfx_button") }

    func setDialogueVoice(_ playing: Bool) {
        if playing && sound && active && screen == .game && simulation == nil {
            if voice?.isPlaying != true { voice = player("voice_talking", loop: true) }
        } else {
            voice?.stop()
            voice = nil
        }
    }

    private func stopEffects() {
        effects.values.forEach { $0.stop() }
        effects.removeAll()
        setDialogueVoice(false)
    }

    private func refreshAudio(restart: Bool = false) {
        guard sound && active else {
            music?.pause()
            ambient?.pause()
            if !sound {
                music = nil
                musicName = nil
                ambient = nil
                stopEffects()
            }
            return
        }
        let next: String?
        switch screen {
        case .home, .map: next = "music_menu"
        case .game:
            next = simulation?.phase == .retry || simulation?.phase == .won ? nil :
                "music_world\(min(3, max(1, level.world + 1)))"
        case .credits: next = "end_song"
        }
        if musicName != next || restart {
            music?.stop()
            musicName = next
            music = next.flatMap { player($0, loop: $0 != "end_song") }
        } else if next != "end_song" || (music?.currentTime ?? 0) > 0 {
            music?.play()
        }
        if screen == .game && level.weather == "rain" && next != nil {
            if ambient == nil { ambient = player("rain", loop: true) } else { ambient?.play() }
        } else {
            ambient?.stop()
            ambient = nil
        }
    }

    private func playEffect(_ name: String) {
        guard sound && active else { return }
        effects[name]?.stop()
        effects[name] = player(name)
    }

    private func player(_ name: String, loop: Bool = false) -> AVAudioPlayer? {
        let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
            Bundle.main.url(forResource: name, withExtension: "wav")
        guard let url, let result = try? AVAudioPlayer(contentsOf: url) else { return nil }
        result.numberOfLoops = loop ? -1 : 0
        result.play()
        return result
    }
}
