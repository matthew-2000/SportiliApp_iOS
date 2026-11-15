import Foundation
import SwiftUI
import UserNotifications
import ActivityKit
import FirebaseAuth

/// All async scheduling is serialized on the main actor and guarded by a generation.
@MainActor
final class PhoneRestTimer: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PhoneRestTimer()
    @Published var message = ""
    private let defaults: UserDefaults
    private let canStart: () -> Bool
    init(defaults: UserDefaults = .standard, canStart: @escaping () -> Bool = { Auth.auth().currentUser != nil }) {
        self.defaults = defaults; self.canStart = canStart; super.init()
    }
    private var requestID: String? { defaults.string(forKey: "rest.request") }
    private var generation = UUID()
    var deadline: Date? { defaults.object(forKey: "rest.deadline") as? Date }
    var remaining: Int { max(0, Int(ceil(deadline?.timeIntervalSinceNow ?? 0))) }
    var duration: Int { defaults.integer(forKey: "rest.duration") }
    func start(seconds: Int, total: Int) {
        stop()
        guard seconds > 0, canStart() else { return }
        let end = Date().addingTimeInterval(Double(seconds))
        defaults.set(end, forKey: "rest.deadline"); defaults.set(total, forKey: "rest.duration")
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
                    content.title = "Recupero terminato"; content.body = "Puoi iniziare la prossima serie."; content.sound = .default
                    try await center.add(UNNotificationRequest(identifier: scheduledID, content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)))
                    if generation != token { center.removePendingNotificationRequests(withIdentifiers: [scheduledID]); return }
                    message = ""
                } else { message = "Avviso non attivo. Consenti le notifiche nelle impostazioni." }
            } catch { message = "Avviso non impostato. Controlla il timer sullo schermo." }
            guard generation == token else { return }
            if #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled, end > Date() {
                do {
                    _ = try Activity.request(attributes: RestAttributes(), content: ActivityContent(state: .init(deadline: end), staleDate: end), pushType: nil)
                } catch { message = "Countdown esterno non disponibile. L’avviso dipende dai permessi notifiche." }
            }
        }
    }
    func stop(preserveAlert: Bool = false) {
        if !preserveAlert { generation = UUID() }
        defaults.removeObject(forKey: "rest.deadline"); defaults.removeObject(forKey: "rest.duration")
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
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
final class SurfaceSession {
    static let shared = SurfaceSession()
    private var auth: AuthStateDidChangeListenerHandle?
    private var observer: NSObjectProtocol?
    func start() {
        UNUserNotificationCenter.current().delegate = PhoneRestTimer.shared
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
