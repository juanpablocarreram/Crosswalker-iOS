import XCTest

#if SWIFT_PACKAGE
  @testable import CrosswalkerCore
#else
  @testable import Crosswalker
#endif

final class PresentationTests: XCTestCase {
  private func fixture() throws -> Reference {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: Self.self)
    #endif
    let url = try XCTUnwrap(
      bundle.url(forResource: "presentation", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
  }
  func testTutorialStepsMatchTheSelectedKotlinBranch() throws {
    let reference = try fixture()
    for sample in reference.tutorial {
      let step = TutorialStep.current(
        index: sample.index, lineCount: sample.count, lookChosen: sample.look,
        panelOpen: sample.open)
      XCTAssertEqual(step.spotlight, sample.spotlight)
      XCTAssertEqual(step.tap, sample.tap)
    }
  }
  func testSpeakerPitchUsesKotlinHash() throws {
    for (speaker, voice) in try fixture().voices {
      XCTAssertEqual(AudioMapping.voiceIndex(speaker: speaker), voice)
    }
  }
  func testMusicMappingCoversAllScreensAndWorlds() {
    XCTAssertEqual(AudioMapping.music(screen: .home, world: 2), "music_menu")
    XCTAssertEqual(AudioMapping.music(screen: .map, world: 1), "music_menu")
    for world in 0...2 {
      XCTAssertEqual(AudioMapping.music(screen: .game, world: world), "music_world\(world + 1)")
    }
    XCTAssertEqual(AudioMapping.music(screen: .credits, world: 2), "end_song")
  }
  func testLexiconUsesWordBoundariesAccentsAndCategoryPriority() throws {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: Self.self)
    #endif
    let url = try XCTUnwrap(
      bundle.url(forResource: "campaign", withExtension: "json", subdirectory: "Fixtures"))
    let campaign = try JSONDecoder().decode(Campaign.self, from: Data(contentsOf: url))
    let text = "Ana mira la calle. Abrir plan en el cruce. Bananana."
    let matches = DialogueLexicon(level: campaign.levels[0], tools: campaign.tools).matches(
      in: text)
    XCTAssertEqual(
      matches.map { (text as NSString).substring(with: $0.range) },
      ["Ana", "la calle", "Abrir plan", "cruce"])
    XCTAssertEqual(matches.map(\.category), [.person, .object, .object, .place])
  }
  private struct Reference: Decodable {
    let tutorial: [Step]
    let voices: [String: Int]
  }
  private struct Step: Decodable {
    let index: Int
    let count: Int
    let look: Bool
    let open: Bool
    let spotlight: String
    let tap: String
  }
}
