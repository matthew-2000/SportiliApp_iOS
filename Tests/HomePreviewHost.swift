// Test-only entry point, substituted into a temporary project by run_home_previews.py.
// The production HomeView and models are unchanged. Firebase is never configured.
import SwiftUI

@main
struct HomePreviewHost: App {
    private let viewModel: SchedaViewModel

    init() {
        let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
            .map { String($0.dropFirst("--scenario=".count)) } ?? "last-week"
        precondition(["last-week", "expired", "requested"].contains(scenario))
        let calendar = Calendar.current
        let daysAgo = scenario == "last-week" ? 22 : 29
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        let card = Scheda(
            dataInizio: start,
            durata: 4,
            giorni: PreviewData.scheda.giorni,
            cambioRichiesto: scenario == "requested"
        )
        viewModel = SchedaViewModel(autoFetchOnInit: false, scheda: card)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(schedaViewModel: viewModel, previewUserName: "Test locale")
            }
            .montserrat(size: 17)
        }
    }
}
