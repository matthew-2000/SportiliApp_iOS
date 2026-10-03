// Test-only entry point, substituted into a temporary project by run_login_previews.py.
// Firebase is never configured and the production app entry point is unchanged.
import SwiftUI

@main
struct LoginPreviewHost: App {
    private let scenario: String
    private let session: LoginSession

    init() {
        scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
            .map { String($0.dropFirst("--scenario=".count)) } ?? "light"
        session = LoginSession(
            read: { _, completion in completion(.failure(NSError(domain: "LocalPreview", code: 1))); return { } },
            signIn: { _, completion in completion(nil) }, save: { _, _ in }
        )
        precondition(["light", "dark", "accessibility", "keyboard", "long-code", "error", "error-large", "keyboard-large"].contains(scenario))
    }

    var body: some Scene {
        WindowGroup {
            LoginView(login: session, initiallyFocused: scenario.hasPrefix("keyboard"),
                initialCode: scenario == "long-code" ? "SPORTILI2026CODICEMOLTOLUNGO1234567890" : "")
                .preferredColorScheme(scenario == "dark" ? .dark : .light)
                .environment(\.dynamicTypeSize, (scenario == "accessibility" || scenario.hasSuffix("-large")) ? .accessibility3 : .large)
                .sportiliTheme()
                .onAppear { if scenario.hasPrefix("error") { session.start(code: "LOCALPREVIEW") } }
        }
    }

}
