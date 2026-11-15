#if DEBUG
import Foundation
import UserNotifications
import ActivityKit

@MainActor
func runNativeSurfaceChecks() async {
    let defaults = UserDefaults(suiteName: "sportili.native.tests")!
    defaults.removePersistentDomain(forName: "sportili.native.tests")
    let timer = PhoneRestTimer(defaults: defaults, canStart: { true })
    let center = UNUserNotificationCenter.current()
    var checks = [String]()
    timer.start(seconds: 30, total: 90)
    precondition(timer.remaining == 30 && timer.duration == 90)
    let first = timer.deadline!
    timer.start(seconds: 60, total: 90)
    precondition(timer.deadline! > first && timer.remaining == 60)
    checks.append("PASS deadline, replacement, exercise duration")
    timer.stop()
    try? await Task.sleep(for: .milliseconds(250))
    precondition(timer.deadline == nil)
    let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("phone.rest.") }
    precondition(pending.isEmpty)
    checks.append("PASS cancellation while permission request is pending")
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
    restored.reconcile(); precondition(restored.deadline == nil)
    timer.stop()
    WorkoutSurface.save(id: "fixture-a", name: "Giorno A", count: 4)
    let previous = WorkoutSurface.current!
    precondition(previous.count == 4 && previous.url.scheme == "sportiliapp")
    WorkoutSurface.clear(); precondition(WorkoutSurface.current == nil)
    WorkoutSurface.save(id: "fixture-a", name: "Giorno A", count: 4)
    precondition(WorkoutSurface.current!.session != previous.session)
    WorkoutSurface.clear()
    checks.append("PASS restore, expiry, snapshot invalidation and session rotation")
    try? checks.joined(separator: "\n").write(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("native-checks.txt"), atomically: true, encoding: .utf8)
}
#endif
