// Test-only host, inserted into a temporary project by run_s11_qa.py.
// Real login, TabView and routes; Firebase is never configured.
import SwiftUI
import UIKit

@main
struct S11PreviewHost: App {
    var body: some Scene {
        WindowGroup {
            Group {
                if S11Fixture.scenario == "login" { LoginView(login: S11Fixture.login()) }
                else { ContentView() }
            }
            .sportiliTheme()
            .environment(\.openURL, OpenURLAction { _ in .handled })
        }
    }
}

enum S11Fixture {
    static let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
        .map { String($0.dropFirst("--scenario=".count)) } ?? "login"
    static let model = makeModel()
    static let details = ExerciseDetailViewModel(userCode: "local-fixture", autoObserve: false,
        initialData: ["plank": UserExerciseData(noteUtente: "Nota della prima parte", weightLogs: ["p1": WeightLog(id: "p1", timestamp: 1_700_000_000_000, weight: 10)]),
            "lite": UserExerciseData(noteUtente: "Nota della terza parte · legacy", weightLogs: ["p3": WeightLog(id: "p3", timestamp: 1_700_000_000_000, weight: 30)])])
    static let actions = ExerciseDetailActions(addWeight: { key, weight, completion in
        let entry = WeightLog(id: "local-new", timestamp: 1_790_000_000_000, weight: weight)
        details.applyS11Fixture(key, note: nil, entry: entry); completion(.success(entry))
    }, updateWeight: { key, id, weight, completion in
        let entry = WeightLog(id: id, timestamp: 1_790_000_000_000, weight: weight)
        details.applyS11Fixture(key, note: nil, entry: entry); completion(.success(entry))
    }, updateNote: { key, note, completion in details.applyS11Fixture(key, note: note); completion(.success(())) })

    static func login() -> LoginSession {
        LoginSession(read: { path, completion in
            let task = DispatchWorkItem {
                if path == "fausto" { completion(.success(nil)) }
                else if path == "users/AB12CD" { completion(.success(["nome": "Matteo"])) }
                else if path == "users/RETE" { completion(.failure(NSError(domain: "local", code: 1))) }
                else { completion(.success(nil)) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
            return { task.cancel() }
        }, signIn: { _, completion in completion(nil) }, save: { _, _ in })
    }
    static func image() -> ImageLoader {
        let loader = ImageLoader()
        loader.error = NSError(domain: "local-image", code: 1)
        return loader
    }
    static func retry() { model.errorMessage = nil; model.scheda = workout; model.hasLoadedOnce = true; model.isLoading = false }
    static var alerts: AlertsViewModel {
        AlertsViewModel(autoObserve: false, initialAlerts: [UserAlert.Urgency.alta, .media, .bassa, .nessuna].compactMap { urgency in
            UserAlert(id: urgency.rawValue, data: ["titolo": "Aggiornamento \(urgency.displayName.lowercased())",
                "descrizione": "Controlla gli orari prima di raggiungere la palestra.", "urgenza": urgency.rawValue])
        })
    }
    static var workout: Scheda {
        let triple = Esercizio(id: "triple", name: "Plank + Distensioni su panca inclinata con manubri e controllo della fase eccentrica + Élite",
            serie: "3 × 40 secondi + 4 × 8–10 + 3 × 12", riposo: "1:30", notePT: "Esegui tutte e tre le parti, poi recupera.")
        let single = Esercizio(id: "single", name: "Plank", serie: "3 × 40 secondi", riposo: "1:30", notePT: "Mantieni il bacino stabile e respira durante tutta la serie.")
        return Scheda(dataInizio: Calendar.current.date(byAdding: .day, value: scenario == "expired" || scenario == "requested" ? -43 : scenario == "expiring" ? -38 : -7, to: Date())!,
            durata: 6, giorni: [Giorno(id: "day-z", name: "Giorno A · Spinta", gruppiMuscolari: [GruppoMuscolare(id: "group-a", nome: "Petto e stabilità", esercizi: [single, triple])])], cambioRichiesto: scenario == "requested")
    }
    private static func makeModel() -> SchedaViewModel {
        let model = SchedaViewModel(autoFetchOnInit: false, scheda: ["empty", "error", "loading"].contains(scenario) ? nil : workout)
        model.hasLoadedOnce = scenario != "loading"
        model.isLoading = scenario == "loading" || scenario == "refreshing"
        if scenario == "error" || scenario == "cached-error" { model.errorMessage = "Errore locale" }
        return model
    }
}
