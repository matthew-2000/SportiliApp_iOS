// Test-only app entry: DEMO Firebase and loopback emulators, never the production plist.
import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase

final class WatchTestDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let config = FirebaseOptions(googleAppID: "1:123456789:ios:0123456789abcdef0123456789abcdef", gcmSenderID: "123456789")
        config.apiKey = "fake-local-key"; config.projectID = "demo-sportili-watch"
        config.databaseURL = "https://demo-sportili-watch-default-rtdb.firebaseio.com"
        FirebaseApp.configure(options: config)
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 19199)
        Database.database().useEmulator(withHost: "127.0.0.1", port: 19100)
        return true
    }
}
@main
struct WatchFirebaseHost: App {
    @UIApplicationDelegateAdaptor(WatchTestDelegate.self) var delegate
    @State private var status = "RUNNING"
    var body: some Scene { WindowGroup { Text(status).task { await runChecks() } } }
    @MainActor private func runChecks() async {
        do {
            _ = try await Auth.auth().signInAnonymously()
            var ledger = PhoneLedger(); ledger.bind(identity: "local:A"); ledger.issuedKeys["panca"] = "legacy_panca"
            let sets = [WatchSet(reps: 12, weight: 30), WatchSet(reps: 10, weight: 35), WatchSet(reps: 8, weight: 40), WatchSet(reps: 6, weight: 45)]
            let record = WatchRecording(binding: ledger.binding!, workoutRevision: "original", exerciseKey: "panca", exerciseName: "Panca", single: nil, sets: sets)
            let root = Database.database().reference()
            try await root.child("users/A/exerciseData/legacy_panca").setValue(["noteUtente": "preserve", "weightLogs": ["old": ["timestamp": 1700000000, "weight": 20]]])
            let path = ledger.path(for: record, code: "A")!
            try require(await save(record, path) == .saved, "insert")
            try require(await save(record, path) == .saved, "retry")
            let sessions = try await root.child("users/A/weightSessions/panca").getData()
            try require(sessions.childrenCount == 1, "duplicate session")
            let parsed = WorkoutWeightSession.parse(id: record.id, value: try await root.child(path).getData().value)
            try require(parsed?.sets.map(\.reps) == [12, 10, 8, 6], "installed model contract")
            var edited = record; edited.sets[0].weight = 42
            try await root.child(path).setValue(edited.firebaseValue)
            try require(await save(record, path) == .conflict, "concurrent edit not protected")
            let preserved = try await root.child(path).getData().value as? NSDictionary
            try require(preserved?.isEqual(to: edited.firebaseValue) == true, "concurrent data overwritten")
            var single = record; single.id = "watch_" + UUID().uuidString.lowercased(); single.single = 50; single.sets = []
            try require(await save(single, ledger.path(for: single, code: "A")!) == .saved, "legacy single")
            try require(await save(single, ledger.path(for: single, code: "A")!) == .saved, "legacy single retry")
            let legacy = try await root.child("users/A/exerciseData/legacy_panca").getData().value as! [String: Any]
            try require(legacy["noteUtente"] as? String == "preserve" && (legacy["weightLogs"] as? [String: Any])?.count == 2, "legacy preservation")
            // Offline operations cannot emit .saved until Firebase commits after reconnect.
            Database.database().goOffline()
            var offline = record; offline.id = "watch_" + UUID().uuidString.lowercased()
            let flag = CallbackFlag()
            WatchFirebaseWriter().save(offline, path: ledger.path(for: offline, code: "A")!) { result in flag.result = result }
            try await Task.sleep(nanoseconds: 500_000_000)
            try require(flag.result == nil, "offline prematurely saved")
            Database.database().goOnline()
            let end = Date().addingTimeInterval(10)
            while flag.result == nil && Date() < end { try await Task.sleep(nanoseconds: 50_000_000) }
            try require(try flag.result?.get() == .saved, "reconnect failed")
            // A rejected write stays retryable; the same UUID can be retried.
            let denied = await save(record, "denied/\(record.id)")
            try require(denied == .retry, "permission/validation error not surfaced")
            ledger.bind(identity: "local:B"); ledger.issuedKeys["panca"] = "panca"
            try require(ledger.receive(record).status == .rejected && ledger.path(for: record, code: "B") == nil, "wrong user path")
            try require(!(try await root.child("users/B").getData()).exists(), "new user contaminated")
            status = "PASS"
        } catch { status = "FAIL: \(error.localizedDescription)" }
        let path = ProcessInfo.processInfo.environment["WATCH_TEST_RESULT"] ?? "/tmp/watch-test-result.txt"
        try? status.write(toFile: path, atomically: true, encoding: .utf8)
    }
    private func save(_ recording: WatchRecording, _ path: String) async -> WatchReceiptStatus {
        await withCheckedContinuation { continuation in
            WatchFirebaseWriter().save(recording, path: path) { result in
                continuation.resume(returning: (try? result.get()) ?? .retry)
            }
        }
    }
    private func require(_ value: Bool, _ message: String) throws { if !value { throw CheckFailure(message: message) } }
}
private final class CallbackFlag { var result: Result<WatchReceiptStatus, Error>? }
private struct CheckFailure: LocalizedError { var message: String; var errorDescription: String? { message } }
