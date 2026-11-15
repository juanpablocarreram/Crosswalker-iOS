import XCTest

final class NavigationTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
        app.launch()
    }

    private func tap(_ label: String) {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 6), label)
        let ready = expectation(for: NSPredicate(format: "isHittable == true AND isEnabled == true"), evaluatedWith: button)
        wait(for: [ready], timeout: 6)
        button.tap()
    }

    func testWorldsProgressionAndPlan() {
        tap("JUGAR")
        tap("MUNDO 2")
        XCTAssertTrue(app.staticTexts["Campus de innovación"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Nivel 5,")).firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Nivel 5,")).firstMatch.isEnabled)
        tap("MUNDO 1")
        tap("Mi primer cruce")
        tap("PREPARAR EL PLAN")
        tap("ABRIR PLAN")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "PONER EL PLAN EN MARCHA")).firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "PONER EL PLAN EN MARCHA")).firstMatch.isEnabled)
    }
}
