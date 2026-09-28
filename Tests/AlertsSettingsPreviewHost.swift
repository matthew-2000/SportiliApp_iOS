// Test-only entry point, substituted into a temporary project by
// run_alerts_settings_previews.py. Firebase is never configured.
import SwiftUI

@main
struct AlertsSettingsPreviewHost: App {
    private let scenario: String

    init() {
        scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
            .map { String($0.dropFirst("--scenario=".count)) } ?? "alerts-loaded"

        precondition([
            "alerts-loaded", "alerts-empty", "alerts-error", "alerts-dark",
            "alerts-accessibility", "settings-light", "settings-dark",
            "settings-accessibility"
        ].contains(scenario))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if scenario.hasPrefix("alerts-") {
                    AlertsView(viewModel: alertsViewModel)
                } else {
                    SettingsView(
                        appVersion: "1.5.3",
                        buildNumber: "15",
                        signOut: {},
                        clearSessionDefaults: {}
                    )
                }
            }
            .montserrat(size: 17)
            .preferredColorScheme(scenario.hasSuffix("dark") ? .dark : .light)
            .environment(
                \.sizeCategory,
                scenario.hasSuffix("accessibility") ? .accessibilityExtraExtraLarge : .large
            )
        }
    }

    private var alertsViewModel: AlertsViewModel {
        switch scenario {
        case "alerts-empty":
            return AlertsViewModel(autoObserve: false)
        case "alerts-error":
            return AlertsViewModel(
                autoObserve: false,
                initialErrorMessage: "Connessione non disponibile. Controlla la rete e riprova."
            )
        default:
            return AlertsViewModel(autoObserve: false, initialAlerts: PreviewData.alerts)
        }
    }
}
