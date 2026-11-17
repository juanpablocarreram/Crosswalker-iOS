import Foundation

final class GameRepository {
  let campaign: Campaign
  private let defaults: UserDefaults
  var worlds: [String] { campaign.worlds }
  var levels: [Level] { campaign.levels }
  var tools: [Tool] { campaign.tools }
  convenience init(bundle: Bundle = .main, defaults: UserDefaults = .standard) throws {
    guard let url = bundle.url(forResource: "campaign", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let campaign = try JSONDecoder().decode(Campaign.self, from: Data(contentsOf: url))
    self.init(campaign: campaign, defaults: defaults)
  }
  init(campaign: Campaign, defaults: UserDefaults = .standard) {
    self.campaign = campaign
    self.defaults = defaults
    defaults.register(defaults: ["sound": true, "guidance": true])
  }
  func stars(_ id: Int) -> Int { defaults.integer(forKey: "stars_\(id)") }
  func unlocked(_ id: Int) -> Bool {
    guard let index = levels.firstIndex(where: { $0.id == id }) else { return false }
    return index == 0 || stars(levels[index - 1].id) > 0
  }
  func nextLevel(after id: Int) -> Level? {
    guard let index = levels.firstIndex(where: { $0.id == id }), index + 1 < levels.count else {
      return nil
    }
    return levels[index + 1]
  }
  var tutorialDone: Bool {
    get { defaults.bool(forKey: "tutorial_done") }
    set { defaults.set(newValue, forKey: "tutorial_done") }
  }
  func resetProgress() {
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("stars_") {
      defaults.removeObject(forKey: key)
    }
    tutorialDone = false
  }
  func save(_ id: Int, stars value: Int) {
    defaults.set(max(value, stars(id)), forKey: "stars_\(id)")
  }
  var sound: Bool {
    get { defaults.bool(forKey: "sound") }
    set { defaults.set(newValue, forKey: "sound") }
  }
  var guidance: Bool {
    get { defaults.bool(forKey: "guidance") }
    set { defaults.set(newValue, forKey: "guidance") }
  }
}
