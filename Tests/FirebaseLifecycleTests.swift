let db = Database.shared
let defaults = UserDefaults.standard
let oldCode = defaults.string(forKey: "code")
let oldAdmin = defaults.object(forKey: "isAdmin")
defer {
    defaults.set(oldCode, forKey: "code")
    defaults.set(oldAdmin, forKey: "isAdmin")
}
func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
func check(_ condition: @autoclosure () -> Bool, _ message: String) { precondition(condition(), message) }

do {
    let login = LoginSession.firebase()
    login.start(code: "")
    check(!login.isLoading && login.errorMessage != nil && db.listeners.isEmpty, "empty code")
}
// Actual Firebase adapter wired to the boundary double: only /users/{code} is read.
do {
    let login = LoginSession.firebase()
    login.start(code: "valid")
    db.emit("fausto", "admin/#")
    check(db.listeners.values.map { $0.0 } == ["users/valid"], "read only the selected profile")
    db.emit("users/valid", ["nome": "Test"])
    check(login.isLoggedIn && !login.isLoading && db.listeners.isEmpty, "valid login and detach")
    check(defaults.string(forKey: "code") == "valid" && !defaults.bool(forKey: "isAdmin"), "user login persisted")
}
do {
    let login = LoginSession.firebase()
    login.start(code: "unknown")
    db.emit("fausto", "admin")
    db.emit("users/unknown", nil)
    check(!login.isLoading && login.errorMessage != nil, "missing code")
    login.start(code: "valid")
    db.deny("fausto")
    check(!login.isLoading && db.listeners.isEmpty, "admin read error releases listener")
    login.start(code: "valid")
    db.emit("fausto", "admin")
    db.deny("users/valid")
    check(!login.isLoading && db.listeners.isEmpty, "profile read error releases listener")
    login.start(code: "valid")
    db.emit("fausto", "admin")
    Auth.shared.error = NSError(domain: "auth", code: 1)
    db.emit("users/valid", ["nome": "Test"])
    check(!login.isLoading && !login.isLoggedIn, "auth error")
    Auth.shared.error = nil
    login.start(code: "valid")
    db.emit("fausto", "admin")
    db.emit("users/valid", ["nome": "Test"])
    check(login.isLoggedIn, "retry succeeds")
}
for code in ["a/b", "a.b", "a#b", "a$b", "a[b", "a]b", "a\u{7f}b", "a\nb", String(repeating: "x", count: 769)] {
    let login = LoginSession.firebase()
    login.start(code: code)
    db.emit("fausto", "admin")
    check(!login.isLoading && db.listeners.isEmpty && !login.isLoggedIn, "invalid path rejected")
}
do {
    let login = LoginSession.firebase()
    login.start(code: "admin/#")
    db.emit("fausto", "admin/#")
    check(login.isLoggedIn && defaults.bool(forKey: "isAdmin"), "legacy admin code accepted")
}
do {
    var login: LoginSession? = .firebase()
    login!.start(code: "valid")
    let late = db.listeners.values.first!.1
    login!.cancel()
    late(DataSnapshot("valid"))
    check(!login!.isLoggedIn && db.listeners.isEmpty, "cancel ignores queued callback")
    login!.start(code: "valid")
    login = nil
    check(db.listeners.isEmpty, "login deinit releases read")
}
do {
    let login = LoginSession.firebase()
    login.start(code: "valid", timeoutInterval: 0.001)
    let late = db.listeners.values.first!.1
    drain()
    check(!login.isLoading && login.errorMessage != nil && db.listeners.isEmpty, "timeout releases read")
    login.start(code: "valid")
    late(DataSnapshot("valid"))
    check(login.isLoading && !login.isLoggedIn, "late response cannot finish retry")
    db.emit("fausto", "admin")
    db.emit("users/valid", ["nome": "Test"])
    check(login.isLoggedIn, "retry after timeout")
}
print("PASS: login valid/missing/invalid, admin, read/auth failures, retry, cancellation and release")

let card: [String: Any] = ["dataInizio": "2026-09-01T12:00:00+0200", "durata": 4]
do {
    var manager: SchedaManager? = SchedaManager()
    var count = 0
    for _ in 0..<8 { manager!.getSchedaFromFirebaseResult(code: "A") { _ in count += 1 } }
    check(db.listeners.count == 1, "repeated refresh has one observer")
    let late = db.listeners.values.first!.1
    manager!.getSchedaFromFirebaseResult(code: "B") { _ in count += 1 }
    late(DataSnapshot(card))
    check(count == 0, "old user callback ignored")
    db.emit("users/B/scheda", card)
    db.emit("users/B/scheda", card.merging(["durata": 6]) { _, new in new })
    check(count == 2, "realtime updates retained")
    db.deny("users/B/scheda")
    check(count == 3 && db.listeners.isEmpty, "observer cancellation releases handle")
    manager!.getSchedaFromFirebaseResult(code: "B") { _ in count += 1 }
    manager = nil
    check(db.listeners.isEmpty, "manager deinit releases observer")
}
do {
    defaults.set("A", forKey: "code")
    var vm: SchedaViewModel? = SchedaViewModel(autoFetchOnInit: false)
    vm!.fetchScheda()
    db.emit("users/A/scheda", card) // Queue the old user's UI response.
    defaults.set("B", forKey: "code")
    vm!.fetchScheda()
    drain()
    check(vm!.scheda == nil, "queued UI callback cannot restore old user")
    db.emit("users/B/scheda", card)
    drain()
    check(vm!.scheda?.durata == 4 && !vm!.isLoading, "new user loaded")
    vm = nil
    check(db.listeners.isEmpty, "view model release detaches observation")
}
print("PASS: repeated refresh, realtime, changed user, queued callbacks, cancellation and deinit")

do {
    defaults.set("A", forKey: "code")
    var vm: SchedaViewModel? = SchedaViewModel()
    db.emit("users/A/scheda", card)
    drain()
    check(vm!.scheda != nil, "initial automatic load")
    defaults.set("B", forKey: "code")
    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    check(vm!.scheda == nil && db.listeners.values.first?.0 == "users/B/scheda", "automatic user switch")
    defaults.removeObject(forKey: "code")
    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    check(!vm!.isLoading && vm!.scheda == nil && db.listeners.isEmpty, "logout removes observation")
    vm = nil
}
print("PASS: automatic user change and logout")
