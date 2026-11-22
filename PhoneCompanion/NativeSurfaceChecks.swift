#if DEBUG
import Foundation
import Combine
import UserNotifications
import ActivityKit

@MainActor
func runNativeSurfaceChecks() async {
    let defaults = UserDefaults(suiteName: "sportili.native.tests")!
    defaults.removePersistentDomain(forName: "sportili.native.tests")
    let timer = PhoneRestTimer(defaults: defaults, canStart: { true })
    let center = UNUserNotificationCenter.current()
    var checks = [String]()
    let resultURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("native-checks.txt")
    try? FileManager.default.removeItem(at: resultURL)
    var observedDeadlines = [Date?]()
    let observation = timer.$deadline.sink { observedDeadlines.append($0) }
    defer { observation.cancel(); timer.stop(); WorkoutSurface.clear() }
    timer.registerNotificationActions()
    try? await Task.sleep(for: .milliseconds(100))
    let categories = await center.notificationCategories()
    let category = categories.first { $0.identifier == "sportili.rest.finished" }
    precondition(category?.actions.map(\.title) == ["Apri timer", "Altri 30 secondi"])
    precondition(category?.actions.allSatisfy { $0.options.contains(.foreground) } == true)
    checks.append("PASS notification actions registered for foreground delivery")
    timer.start(seconds: 30, total: 90, exerciseName: "Panca piana")
    precondition(timer.remaining == 30 && timer.duration == 90)
    let first = timer.deadline!
    let firstRequest = defaults.string(forKey: "rest.request")!
    precondition(observedDeadlines.contains { $0 == first })
    precondition(timer.exerciseName == "Panca piana")
    let metadata = PhoneRestTimer(defaults: defaults, canStart: { true })
    precondition(metadata.deadline == first && metadata.duration == 90 && metadata.exerciseName == "Panca piana")
    timer.start(seconds: 60, total: 90)
    precondition(timer.deadline! > first && timer.remaining == 60)
    precondition(!timer.handleNotificationAction("sportili.rest.extend", requestIdentifier: firstRequest, data: [:]))
    checks.append("PASS published deadline, replacement, exercise duration and persisted exercise")
    timer.stop()
    try? await Task.sleep(for: .milliseconds(250))
    precondition(timer.deadline == nil)
    let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("phone.rest.") }
    precondition(pending.isEmpty)
    precondition(!timer.handleNotificationAction("sportili.rest.open", requestIdentifier: firstRequest, data: [:]))
    checks.append("PASS cancellation while permission request is pending; stale actions rejected")
    timer.start(seconds: 60, total: 90, exerciseName: "Panca piana")
    let currentRequest = defaults.string(forKey: "rest.request")!
    precondition(timer.handleNotificationAction("sportili.rest.extend", requestIdentifier: currentRequest,
        data: ["duration": 90, "exerciseName": "Panca piana"]))
    precondition(timer.remaining == 30 && timer.duration == 90 && timer.exerciseName == "Panca piana")
    precondition(!timer.handleNotificationAction("sportili.rest.extend", requestIdentifier: currentRequest, data: [:]))
    timer.stop()
    checks.append("PASS extra 30 seconds replaces request and rejects duplicate action")
    timer.start(seconds: 2, total: 2)
    try? await Task.sleep(for: .milliseconds(400))
    let settings = await center.notificationSettings()
    let scheduled = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("phone.rest.") }
    if settings.authorizationStatus == .authorized { precondition(scheduled.count == 1); checks.append("PASS one final notification scheduled") }
    else { checks.append("PASS denied permission: timer persists, no promised alert") }
    let restored = PhoneRestTimer(defaults: defaults, canStart: { true })
    precondition(restored.deadline == timer.deadline)
    try? await Task.sleep(for: .seconds(2))
    precondition(restored.remaining == 0)
    restored.reconcile()
    precondition(restored.deadline == nil && restored.completedAt != nil && restored.duration == 2)
    restored.dismissCompletion()
    precondition(restored.completedAt == nil)
    timer.stop()
    WorkoutSurface.save(id: "fixture-a", name: "Giorno A", count: 4)
    let previous = WorkoutSurface.current!
    precondition(previous.count == 4 && previous.url.scheme == "sportiliapp")
    WorkoutSurface.clear(); precondition(WorkoutSurface.current == nil)
    WorkoutSurface.save(id: "fixture-a", name: "Giorno A", count: 4)
    precondition(WorkoutSurface.current!.session != previous.session)
    WorkoutSurface.clear()
    checks.append("PASS restore, expiry, snapshot invalidation and session rotation")
    try? checks.joined(separator: "\n").write(to: resultURL, atomically: true, encoding: .utf8)
}
#endif
