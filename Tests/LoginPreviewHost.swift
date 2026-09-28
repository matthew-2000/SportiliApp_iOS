// Test-only entry point, substituted into a temporary project by run_login_previews.py.
// Firebase is never configured and the production app entry point is unchanged.
import SwiftUI

@main
struct LoginPreviewHost: App {
    private let scenario: String

    init() {
        scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
            .map { String($0.dropFirst("--scenario=".count)) } ?? "light"
        precondition(["light", "dark", "accessibility", "keyboard"].contains(scenario))
    }

    var body: some Scene {
        WindowGroup {
            LoginView(login: previewSession, initiallyFocused: scenario == "keyboard")
                .preferredColorScheme(scenario == "dark" ? .dark : .light)
                .environment(\.dynamicTypeSize, scenario == "accessibility" ? .accessibility3 : .large)
                .montserrat(size: 17)
        }
    }

    private var previewSession: LoginSession {
        LoginSession(
            read: { _, _ in { } },
            signIn: { _, completion in completion(nil) },
            save: { _, _ in }
        )
    }
}
