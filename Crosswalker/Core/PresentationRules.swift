import Foundation

enum Screen: Equatable { case home, map, game, credits }
enum ScreenMotion: Equatable {
  case forward, backward, fade
  var backwards: Bool { self == .backward }
}

/// Durations read from the selected Android branch, in seconds.
enum PresentationTiming {
  static let frameNanoseconds: UInt64 = 50_000_000
  static let dialogueNanoseconds: UInt64 = 25_000_000
  static let resultNanoseconds: UInt64 = 900_000_000
  static let screenTransition = 0.7
  static let openingIris = 0.82
}

struct TutorialStep: Equatable {
  let spotlight: String
  let tap: String
  init(_ spotlight: String, tap: String? = nil) {
    self.spotlight = spotlight
    self.tap = tap ?? spotlight
  }
  static func current(index: Int, lineCount: Int, lookChosen: Bool, panelOpen: Bool) -> TutorialStep
  {
    if !panelOpen {
      return index == 2
        ? TutorialStep("board", tap: "planning_panel") : TutorialStep("planning_panel")
    }
    if index < lineCount - 1 {
      switch index {
      case 0...3: return TutorialStep("dialogue")
      case 4: return TutorialStep("pause", tap: "dialogue")
      case 5: return TutorialStep("tokens", tap: "dialogue")
      case 6: return TutorialStep("walkers", tap: "dialogue")
      case 7: return TutorialStep("tab_skill", tap: "dialogue")
      case 8: return TutorialStep("tab_street", tap: "dialogue")
      default: return TutorialStep("crossing", tap: "dialogue")
      }
    }
    if index == lineCount - 1 { return TutorialStep("crossing") }
    return TutorialStep(lookChosen ? "launch" : "tool_look")
  }
}

enum AudioMapping {
  static func music(screen: Screen, world: Int) -> String {
    switch screen {
    case .home, .map: return "music_menu"
    case .credits: return "end_song"
    case .game: return "music_world\(world == 0 ? 1 : world == 1 ? 2 : 3)"
    }
  }
  /// Kotlin String.hashCode() uses signed 32-bit arithmetic over UTF-16 code units.
  static func voiceIndex(speaker: String) -> Int {
    var hash: Int32 = 0
    for unit in speaker.utf16 { hash = hash &* 31 &+ Int32(unit) }
    return Int(abs(Int64(hash)) % 6)
  }
}

struct DialogueLexicon {
  enum Category: Equatable { case person, object, place }
  struct Match {
    let range: NSRange
    let category: Category
  }
  private let categories: [String: Category]
  init(level: Level, tools: [Tool]) {
    var result: [String: Category] = [:]
    for place in [
      "calle", "cruce", "banqueta", "carril", "escuela", "ciudad", "barrio", "acera", "esquina",
      "camino", "paso", "mapa del cruce",
    ] {
      result[Self.normalize(place)] = .place
    }
    let controls = [
      "abrir plan", "cerrar plan", "poner el plan en marcha", "habilidades", "la calle", "pausa",
      "fichas", "pestaña", "panel", "mirar", "izquierda", "centro", "derecha",
    ]
    for object in tools.map(\.label) + controls { result[Self.normalize(object)] = .object }
    for walker in level.walkers { result[Self.normalize(walker.name)] = .person }
    categories = result
  }
  private static func normalize(_ text: String) -> String {
    var text = text.lowercased()
    for (accent, plain) in zip(["á", "é", "í", "ó", "ú"], ["a", "e", "i", "o", "u"]) {
      text = text.replacingOccurrences(of: accent, with: plain)
    }
    return text
  }
  func matches(in text: String) -> [Match] {
    let terms = categories.keys.sorted { $0.count == $1.count ? $0 < $1 : $0.count > $1.count }
      .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
    guard !terms.isEmpty,
      let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}])(?:\(terms))(?![\\p{L}])")
    else { return [] }
    let normalized = Self.normalize(text) as NSString
    return regex.matches(
      in: normalized as String, range: NSRange(location: 0, length: normalized.length)
    ).compactMap { match in
      categories[normalized.substring(with: match.range)].map {
        Match(range: match.range, category: $0)
      }
    }
  }
}
