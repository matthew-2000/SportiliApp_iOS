// Test-only entry point, substituted into a temporary project by run_home_previews.py.
// The production HomeView and models are unchanged. Firebase is never configured.
import SwiftUI

@main
struct HomePreviewHost: App {
    private let viewModel: SchedaViewModel

    init() {
        let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
            .map { String($0.dropFirst("--scenario=".count)) } ?? "active"
        precondition([
            "active", "expiring", "expired", "requested", "empty", "error", "dark", "accessibility", "cached-error", "refreshing", "loading", "expired-dark", "error-large", "empty-large", "cached-error-large"
        ].contains(scenario))

        let model: SchedaViewModel
        switch scenario {
        case "empty", "empty-large":
            model = SchedaViewModel(autoFetchOnInit: false)
            model.hasLoadedOnce = true
        case "error", "error-large":
            model = SchedaViewModel(autoFetchOnInit: false)
            model.hasLoadedOnce = true
            model.errorMessage = "Errore di rete simulato"
        case "expiring":
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.expiringScheda)
        case "expired", "expired-dark":
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.expiredScheda)
        case "requested":
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.requestedScheda)
        default:
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.activeScheda)
        }
        if scenario == "loading" { model.scheda = nil; model.isLoading = true; model.hasLoadedOnce = false }
        if scenario == "refreshing" { model.isLoading = true }
        if scenario.hasPrefix("cached-error") { model.errorMessage = "Errore di rete simulato" }
        if let current = model.scheda {
            model.scheda = Scheda(dataInizio: current.dataInizio, durata: current.durata,
                giorni: [PreviewData.giorno, PreviewData.longNamesDay].map { day in
                    Giorno(id: day.id, name: day.name, gruppiMuscolari: day.gruppiMuscolari.map {
                        GruppoMuscolare(id: $0.id, nome: $0.nome, esercizi: [])
                    })
                }, cambioRichiesto: current.cambioRichiesto)
        }
        viewModel = model
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(schedaViewModel: viewModel, previewUserName: "Matteo")
            }
            .sportiliTheme()
            .environment(\.sizeCategory, ProcessInfo.processInfo.arguments.contains { $0 == "--scenario=accessibility" || $0.hasSuffix("-large") } ? .accessibilityExtraExtraLarge : .large)
            .preferredColorScheme(
                ProcessInfo.processInfo.arguments.contains { $0 == "--scenario=dark" || $0.hasSuffix("-dark") } ? .dark : .light
            )
        }
    }
}
