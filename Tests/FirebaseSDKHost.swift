// Test-only entry point, substituted into a temporary project.
import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase

final class LocalFirebaseDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let options = FirebaseOptions(
            googleAppID: "1:123456789:ios:0123456789abcdef0123456789abcdef",
            gcmSenderID: "123456789"
        )
        options.apiKey = "fake-local-key"
        options.projectID = "demo-sportili-compat"
        options.databaseURL = "https://demo-sportili-compat.firebaseio.com"
        FirebaseApp.configure(options: options)
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 19099)
        Database.database().useEmulator(withHost: "127.0.0.1", port: 19000)
        return true
    }
}

@main
struct FirebaseSDKHost: App {
    @UIApplicationDelegateAdaptor(LocalFirebaseDelegate.self) var delegate
    @State private var status = "RUNNING"

    var body: some Scene {
        WindowGroup {
            Text(status).task { await run() }
        }
    }

    @MainActor
    private func run() async {
        do {
            try await runLoginChecks()
            try await runObserverChecks()
            try await runNoteChecks()
            status = "PASS"
            try? await Database.database().reference().child("integrationResults/ios").setValue("PASS")
        } catch {
            status = "FAIL: \(error.localizedDescription)"
            try? await Database.database().reference().child("integrationResults/ios").setValue(status)
        }
    }

    @MainActor
    private func runLoginChecks() async throws {
        try await login("valid", shouldSucceed: true)
        try await login("missing", shouldSucceed: false)
        try await login("a/b", shouldSucceed: false)
        try await login("read-denied", shouldSucceed: false)
        try await login("valid", shouldSucceed: true)
    }

    @MainActor
    private func login(_ code: String, shouldSucceed: Bool) async throws {
        let session = LoginSession.firebase()
        session.start(code: code, timeoutInterval: 5)
        let deadline = Date().addingTimeInterval(8)
        while session.isLoading && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard session.isLoggedIn == shouldSucceed, !session.isLoading else {
            throw Failure("login \(code): \(session.errorMessage ?? "nessun messaggio")")
        }
        if !shouldSucceed, session.errorMessage == nil { throw Failure("missing login error \(code)") }
    }

    @MainActor
    private func runObserverChecks() async throws {
        UserDefaults.standard.set("A", forKey: "code")
        let viewModel = SchedaViewModel(autoFetchOnInit: false)
        for _ in 0..<5 { viewModel.fetchScheda() }
        try await waitUntil { viewModel.scheda?.durata == 4 && !viewModel.isLoading }
        UserDefaults.standard.set("B", forKey: "code")
        viewModel.fetchScheda()
        try await waitUntil { viewModel.scheda?.durata == 6 && !viewModel.isLoading }
        try await setValue(9, path: "users/A/scheda/durata")
        try await Task.sleep(nanoseconds: 300_000_000)
        guard viewModel.scheda?.durata == 6 else { throw Failure("old user response") }
        try await setValue(8, path: "users/B/scheda/durata")
        try await waitUntil { viewModel.scheda?.durata == 8 }
    }

    @MainActor
    private func runNoteChecks() async throws {
        let model = ExerciseDetailViewModel(userCode: "notes")
        try await waitUntil { model.data(for: "panca")?.weightLogs["log1"] != nil }
        let _: Void = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            model.updateUserNote(for: "panca", note: "nuova") { result in
                switch result {
                case .success: continuation.resume(returning: ())
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
        let exerciseData = try await value(at: "users/notes/exerciseData") as? [String: Any]
        let snapshot = exerciseData?["panca"] as? [String: Any]
        guard snapshot?["noteUtente"] as? String == "nuova",
              snapshot?["future"] as? String == "keep",
              (snapshot?["weightLogs"] as? [String: Any])?["log1"] != nil else {
            throw Failure("note/history/unknown preservation: \(String(describing: snapshot))")
        }
    }

    @MainActor
    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(8)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        if !condition() { throw Failure("timeout") }
    }

    private func setValue(_ value: Any, path: String) async throws {
        try await Database.database().reference().child(path).setValue(value)
    }

    private func value(at path: String) async throws -> Any? {
        try await Database.database().reference().child(path).getData().value
    }
}

private struct Failure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
