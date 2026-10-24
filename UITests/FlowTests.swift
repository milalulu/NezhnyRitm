import XCTest

final class FlowTests: XCTestCase {
    func testJournalAndReportFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 10))
        capture("01-home", app: app)
        app.tabBars.buttons["Питание"].tap()
        app.buttons["addMeal"].tap()
        let meal = app.textViews["mealText"]
        let field = app.textFields["mealText"]
        if meal.waitForExistence(timeout: 3) { meal.tap(); meal.typeText("Каша и ягоды") }
        else { XCTAssertTrue(field.exists); field.tap(); field.typeText("Каша и ягоды") }
        app.buttons["saveMeal"].tap()
        XCTAssertTrue(app.staticTexts["Каша и ягоды"].waitForExistence(timeout: 5))
        capture("02-food", app: app)
        app.tabBars.buttons["Шаги"].tap()
        let steps = app.textFields["manualSteps"]
        app.swipeUp()
        XCTAssertTrue(steps.waitForExistence(timeout: 3))
        steps.tap(); steps.typeText("2345")
        app.buttons["Сохранить шаги"].tap()
        XCTAssertTrue(app.staticTexts["stepsSaved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Мой ритм"].waitForExistence(timeout: 5))
        app.swipeDown()
        capture("03-steps", app: app)
        app.tabBars.buttons["Мой ритм"].tap()
        app.buttons["Отчёт для Астраси"].tap()
        app.buttons["generateReport"].tap()
        let report = app.textViews["reportText"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        let value = report.value as? String ?? ""
        XCTAssertTrue(value.contains("Каша и ягоды"))
        XCTAssertTrue(value.contains("2345"))
        capture("04-report", app: app)
    }
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
