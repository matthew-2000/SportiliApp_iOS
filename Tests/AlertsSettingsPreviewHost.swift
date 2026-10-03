// Test-only entry point substituted into a temporary copy. Firebase is never configured.
import SwiftUI

@main
struct AlertsSettingsPreviewHost: App {
    private let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
        .map { String($0.dropFirst("--scenario=".count)) } ?? "alerts-loaded"

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if scenario.hasPrefix("alerts-") {
                    AlertsView(viewModel: alertsViewModel)
                } else {
                    SettingsView(
                        appVersion: "1.5.3",
                        buildNumber: "15",
                        signOut: {
                            if scenario.contains("logout-error") {
                                throw NSError(domain: "local-fixture", code: 1)
                            }
                        },
                        clearSessionDefaults: {}
                    )
                    .environment(\.openURL, OpenURLAction { url in
                        print("S06 local link: \(url.absoluteString)")
                        return scenario.contains("link-error") ? .discarded : .handled
                    })
                }
            }
            .sportiliTheme()
            .preferredColorScheme(scenario.hasSuffix("dark") ? .dark : .light)
            .environment(
                \.sizeCategory,
                scenario.hasSuffix("accessibility") ? .accessibilityExtraExtraLarge : .large
            )
        }
    }

    private var alertsViewModel: AlertsViewModel {
        if scenario.contains("empty") { return AlertsViewModel(autoObserve: false) }
        if scenario.contains("error") {
            return AlertsViewModel(autoObserve: false,
                initialErrorMessage: "Connessione non disponibile. Controlla la rete e riprova.")
        }
        if scenario.contains("loading") { return AlertsViewModel(autoObserve: false, initialLoading: true) }
        if scenario.contains("long") {
            return AlertsViewModel(autoObserve: false, initialAlerts: [makeAlert(.alta, long: true)])
        }
        return AlertsViewModel(autoObserve: false,
            initialAlerts: [.alta, .media, .bassa, .nessuna].map { makeAlert($0) })
    }

    private func makeAlert(_ urgency: UserAlert.Urgency, long: Bool = false) -> UserAlert {
        var data: [String: Any] = [
            "titolo": long
                ? "Chiusura straordinaria della sala pesi e aggiornamento degli orari dei corsi serali durante la manutenzione"
                : "Aggiornamento \(urgency.displayName.lowercased())",
            "descrizione": long
                ? "Durante la manutenzione della sala pesi, gli allenamenti e i corsi serali si svolgeranno nella sala al primo piano. Chiedi al trainer come adattare la tua scheda e controlla gli orari prima di raggiungere la palestra. Grazie per la collaborazione."
                : "Controlla gli orari prima di raggiungere la palestra.",
            "urgenza": urgency.rawValue
        ]
        if urgency != .nessuna {
            data["scadenza"] = Date().addingTimeInterval(86400 * 5).timeIntervalSince1970 * 1000
        }
        return UserAlert(id: urgency.rawValue, data: data)!
    }
}
