import XCTest

final class S11UITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    private func launch(_ scenario: String = "login") {
        app = XCUIApplication(bundleIdentifier: "com.sportili.local-s11-preview")
        app.launchArguments = ["--local-preview", "--scenario=\(scenario)"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-accessibility"; tree.lifetime = .keepAlways; add(tree)
    }
    private func reveal(_ element: XCUIElement, limit: Int = 18) {
        for attempt in 0..<limit {
            if element.exists && element.isHittable { return }
            // A screen-wide swipe starts inside the keyboard at maximum Dynamic Type.
            // Drive the visible scroll viewport instead, as a finger would.
            let containers = app.collectionViews.allElementsBoundByIndex + app.tables.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex
            let container = containers.last { $0.isHittable && $0.frame.height > 80 }
            let frame = container?.frame ?? app.frame
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : frame.maxY
            let bottom = min(frame.maxY, keyboardTop) - 12
            let navigationBottom = app.navigationBars.allElementsBoundByIndex
                .filter { $0.isHittable }.map { $0.frame.maxY }.max() ?? app.frame.minY
            let top = max(frame.minY, navigationBottom) + 24
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let lower = bottom - (bottom - top) * 0.15
            let upper = top + (bottom - top) * 0.15
            let above = element.exists ? element.frame.midY < top : attempt >= limit / 2
            origin.withOffset(CGVector(dx: frame.midX, dy: above ? upper : lower))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: frame.midX, dy: above ? lower : upper)))
        }
        capture("unreachable-control")
        XCTFail("Element unreachable: \(element)")
    }
    private func tap(_ title: String) {
        let element = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title)).firstMatch
        reveal(element); element.tap()
    }
    private func login() {
        let field = app.textFields["Codice di accesso"]
        reveal(field); field.tap(); field.typeText("AB12CD")
        tap("Accedi")
        XCTAssertTrue(app.tabBars.buttons["Scheda"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Scheda"].isSelected)
    }
    private func openDetail() {
        tap("Giorno A · Spinta"); tap("Plank")
        XCTAssertTrue(app.buttons["Avvia timer di recupero"].waitForExistence(timeout: 5))
    }
    func testCompleteNavigationAndLogout() {
        launch(); capture("login"); login(); capture("home")
        tap("Giorno A · Spinta"); capture("day"); tap("Plank"); capture("detail")
        XCTAssertTrue(app.tabBars.buttons["Scheda"].isSelected)
        app.tabBars.buttons["Avvisi"].tap(); capture("alerts")
        XCTAssertTrue(app.tabBars.buttons["Avvisi"].isSelected)
        app.tabBars.buttons["Scheda"].tap()
        XCTAssertTrue(app.buttons["Avvia timer di recupero"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Petto e stabilità"].waitForExistence(timeout: 4))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Impostazioni"].tap(); capture("settings")
        tap("Instagram"); XCTAssertTrue(app.staticTexts["Palestra Sportilia"].exists)
        tap("Esci dall’account"); capture("logout-confirmation")
        if app.buttons["Annulla"].exists { app.buttons["Annulla"].tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap() }
        XCTAssertTrue(app.tabBars.buttons["Impostazioni"].isSelected)
        tap("Esci dall’account")
        let confirmLogout = app.buttons["Esci"]
        reveal(confirmLogout); confirmLogout.tap()
        XCTAssertTrue(app.textFields["Codice di accesso"].waitForExistence(timeout: 5)); capture("logout-login")
    }
    func testLocalWeightNoteAndTimer() {
        launch(); login(); openDetail()
        tap("Avvia timer di recupero"); capture("timer")
        tap("Inizia"); tap("Pausa"); tap("Azzera"); tap("Chiudi")
        tap("Registra peso")
        let weight = app.textFields["Peso (kg)"]
        XCTAssertTrue(weight.waitForExistence(timeout: 4)); weight.tap(); weight.typeText("47,5")
        capture("weight-keyboard"); tap("Salva")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '47' AND label CONTAINS 'kg'")).firstMatch.waitForExistence(timeout: 4))
        capture("weight-saved")
        tap("Modifica nota personale")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 4)); editor.tap()
        editor.press(forDuration: 1.1)
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap(); editor.typeText("Nota locale S11") }
        else { editor.typeText(" Nota locale S11") }
        capture("notes-keyboard"); tap("Chiudi")
        tap("Continua a modificare")
        XCTAssertTrue(app.textViews.firstMatch.value as? String != "Nota della prima parte")
        tap("Salva"); capture("notes-saved")
    }
    func testInvalidNetworkHelpAndExpiredNavigation() {
        launch()
        tap("Accedi"); capture("login-empty-error")
        let field = app.textFields["Codice di accesso"]
        reveal(field); field.tap(); field.typeText("ERRATO"); tap("Accedi")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Codice non autorizzato'")).firstMatch.waitForExistence(timeout: 5))
        capture("login-invalid")
        reveal(field); field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "RETE")
        tap("Accedi")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Errore durante il recupero del profilo'")).firstMatch.waitForExistence(timeout: 5))
        capture("login-network")
        tap("Non hai il codice?"); XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 4)); capture("login-help"); app.alerts.buttons["OK"].tap()
        app.terminate(); launch("expired"); capture("expired")
        tap("Giorno A · Spinta"); tap("Plank")
        XCTAssertTrue(app.buttons["Avvia timer di recupero"].exists)
    }
    func testHomeStatesAndRetryKeepTabsReachable() {
        for state in ["empty", "error", "cached-error", "refreshing", "requested", "expiring", "loading"] {
            launch(state); capture("home-\(state)")
            XCTAssertTrue(app.tabBars.buttons["Scheda"].isSelected)
            app.tabBars.buttons["Avvisi"].tap()
            XCTAssertTrue(app.tabBars.buttons["Avvisi"].isSelected)
            app.tabBars.buttons["Scheda"].tap()
            if state == "error" || state == "cached-error" {
                tap("Riprova")
                tap("Giorno A · Spinta")
                XCTAssertTrue(app.staticTexts["Petto e stabilità"].waitForExistence(timeout: 4))
            }
        }
    }
}
