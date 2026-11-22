import Foundation
import SwiftUI
import UIKit
import UserNotifications
import ActivityKit
import FirebaseAuth

private enum RestNotification {
    static let category = "sportili.rest.finished"
    static let open = "sportili.rest.open"
    static let extend = "sportili.rest.extend"
}

/// All async scheduling is serialized on the main actor and guarded by a generation.
@MainActor
final class PhoneRestTimer: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PhoneRestTimer()
    @Published var message = ""
    @Published private(set) var deadline: Date?
    @Published private(set) var exerciseName: String?
    @Published private(set) var completedAt: Date?
    @Published var isTimerPresented = false
    private var completedDuration = 0
    private var needsLiveActivity = false
    private let defaults: UserDefaults
    private let canStart: () -> Bool
    init(defaults: UserDefaults = .standard, canStart: @escaping () -> Bool = {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--qa-screen=recovery") { return true }
#endif
        return Auth.auth().currentUser != nil
    }) {
        self.defaults = defaults
        self.canStart = canStart
        self.deadline = defaults.object(forKey: "rest.deadline") as? Date
        self.exerciseName = defaults.string(forKey: "rest.exercise")
        super.init()
    }
    private var requestID: String? { defaults.string(forKey: "rest.request") }
    private var generation = UUID()
    var remaining: Int { max(0, Int(ceil(deadline?.timeIntervalSinceNow ?? 0))) }
    var duration: Int { (defaults.object(forKey: "rest.duration") as? Int) ?? completedDuration }
    var startedAt: Date? { deadline.map { $0.addingTimeInterval(-Double(max(duration, 1))) } }

    func start(seconds: Int, total: Int, exerciseName: String? = nil) {
        stop()
        guard seconds > 0, canStart() else { return }
        let end = Date().addingTimeInterval(Double(seconds))
        let name = exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.exerciseName = name?.isEmpty == false ? name : nil
        defaults.set(end, forKey: "rest.deadline")
        defaults.set(max(total, seconds), forKey: "rest.duration")
        defaults.set(self.exerciseName, forKey: "rest.exercise")
        deadline = end
        let token = generation
        let scheduledID = "phone.rest." + token.uuidString
        defaults.set(scheduledID, forKey: "rest.request")
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let allowed = try await center.requestAuthorization(options: [.alert, .sound])
                guard generation == token else { return }
                if allowed && end > Date() {
                    let content = UNMutableNotificationContent()
                    content.title = "Recupero terminato"
                    content.subtitle = self.exerciseName ?? ""
                    content.body = "Puoi iniziare la prossima serie. Se serve, aggiungi 30 secondi."
                    content.sound = .default
                    content.categoryIdentifier = RestNotification.category
                    content.threadIdentifier = "sportili.rest"
                    content.userInfo = ["duration": max(total, seconds), "exerciseName": self.exerciseName ?? ""]
                    try await center.add(UNNotificationRequest(identifier: scheduledID, content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)))
                    if generation != token { center.removePendingNotificationRequests(withIdentifiers: [scheduledID]); return }
                } else if !allowed {
                    message = "Avviso non attivo. Consenti le notifiche nelle impostazioni."
                }
            } catch {
                guard generation == token else { return }
                message = "Avviso non impostato. Controlla il timer sullo schermo."
            }
        }
        needsLiveActivity = true
        startDeferredLiveActivity()
    }

    /// Foreground notification actions can arrive before the scene becomes active.
    func startDeferredLiveActivity() {
        guard needsLiveActivity, let end = deadline, end > Date(),
              UIApplication.shared.applicationState == .active else { return }
        needsLiveActivity = false
        if #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: RestAttributes(exerciseName: exerciseName),
                    content: ActivityContent(state: .init(deadline: end, startedAt: startedAt), staleDate: end), pushType: nil)
            } catch {
                message = "Countdown esterno non disponibile. L’avviso dipende dai permessi notifiche."
            }
        }
    }

    func stop(preserveAlert: Bool = false) {
        needsLiveActivity = false
        if !preserveAlert { generation = UUID() }
        if preserveAlert {
            completedDuration = duration
            completedAt = Date()
        } else {
            completedDuration = 0
            completedAt = nil
            exerciseName = nil
            message = ""
        }
        defaults.removeObject(forKey: "rest.deadline")
        defaults.removeObject(forKey: "rest.duration")
        defaults.removeObject(forKey: "rest.exercise")
        deadline = nil
        if !preserveAlert, let requestID {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [requestID])
        }
        if !preserveAlert { defaults.removeObject(forKey: "rest.request") }
        if #available(iOS 16.2, *) {
            let activities = Activity<RestAttributes>.activities
            Task { for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) } }
        }
    }
    func reconcile() { if deadline != nil && remaining == 0 { stop(preserveAlert: true) } }
    func refreshAuthorization() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied { message = "Avviso non attivo. Consenti le notifiche nelle impostazioni." }
        }
    }
    func dismissCompletion() {
        completedAt = nil
        completedDuration = 0
        exerciseName = nil
    }

    func registerNotificationActions() {
        UNUserNotificationCenter.current().getNotificationCategories { categories in
            let open = UNNotificationAction(identifier: RestNotification.open, title: "Apri timer", options: [.foreground])
            let extend = UNNotificationAction(identifier: RestNotification.extend, title: "Altri 30 secondi", options: [.foreground])
            let category = UNNotificationCategory(identifier: RestNotification.category,
                actions: [open, extend], intentIdentifiers: [], options: [])
            var updated = Set(categories.filter { $0.identifier != RestNotification.category })
            updated.insert(category)
            UNUserNotificationCenter.current().setNotificationCategories(updated)
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard notification.request.identifier.hasPrefix("phone.rest.") else {
            completionHandler([.banner, .sound])
            return
        }
        Task { @MainActor in
            SurfaceSession.shared.refresh()
            guard notification.request.identifier == self.requestID, self.canStart() else {
                completionHandler([])
                return
            }
            self.reconcile()
            // The app shows its own completion bar; the OS owns the single audible alert.
            completionHandler([.sound])
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            SurfaceSession.shared.refresh()
            guard self.handleNotificationAction(response.actionIdentifier,
                requestIdentifier: response.notification.request.identifier,
                data: response.notification.request.content.userInfo) else { return }

            SurfaceRoute.shared.url = URL(string: "sportiliapp://rest")
        }
    }

    /// Shared by the OS delegate and local checks; it rejects replaced/cancelled requests.
    @discardableResult
    func handleNotificationAction(_ action: String, requestIdentifier: String, data: [AnyHashable: Any]) -> Bool {
        guard requestIdentifier == requestID, canStart(),
          [UNNotificationDefaultActionIdentifier, RestNotification.open, RestNotification.extend].contains(action) else { return false }
        let total = max(1, (data["duration"] as? Int) ?? duration)
        let name = (data["exerciseName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        if action == RestNotification.extend {
            start(seconds: 30, total: total, exerciseName: name)
        } else {
            reconcile()
            if deadline == nil {
                completedDuration = total
                exerciseName = name
                completedAt = Date()
            }
        }
        return true
    }

}

@MainActor
final class SurfaceSession {
    static let shared = SurfaceSession()
    private var auth: AuthStateDidChangeListenerHandle?
    private var observer: NSObjectProtocol?
    func start() {
        UNUserNotificationCenter.current().delegate = PhoneRestTimer.shared
        PhoneRestTimer.shared.registerNotificationActions()
        auth = Auth.auth().addStateDidChangeListener { _, _ in Task { @MainActor in self.refresh() } }
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in self.refresh() }
        }
        refresh()
    }
    func refresh() {
        let d = UserDefaults.standard
        let identity = (Auth.auth().currentUser?.uid ?? "") + ":" + (d.string(forKey: "code") ?? "")
        if d.string(forKey: "surface.identity") != identity {
            d.set(identity, forKey: "surface.identity")
            WorkoutSurface.clear(); PhoneRestTimer.shared.stop()
        }
    }
}

@MainActor
final class SurfaceRoute: ObservableObject {
    static let shared = SurfaceRoute()
    @Published var url: URL?
}
