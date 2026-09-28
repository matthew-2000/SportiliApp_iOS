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
            "active", "expiring", "expired", "requested", "empty", "error", "dark"
        ].contains(scenario))

        let model: SchedaViewModel
        switch scenario {
        case "empty":
            model = SchedaViewModel(autoFetchOnInit: false)
            model.hasLoadedOnce = true
        case "error":
            model = SchedaViewModel(autoFetchOnInit: false)
            model.hasLoadedOnce = true
            model.errorMessage = "Errore di rete simulato"
        case "expiring":
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.expiringScheda)
        case "expired":
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.expiredScheda)
        case "requested":
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.requestedScheda)
        default:
            model = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.activeScheda)
        }
        viewModel = model
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(schedaViewModel: viewModel, previewUserName: "Test locale")
            }
            .montserrat(size: 17)
            .preferredColorScheme(
                ProcessInfo.processInfo.arguments.contains("--scenario=dark") ? .dark : .light
            )
        }
    }
}
