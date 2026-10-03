// Replaces only the entry point of a temporary project. No Firebase configuration.
import SwiftUI
import UIKit

@main
struct S04PreviewHost: App {
    private let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
        .map { String($0.dropFirst("--scenario=".count)) } ?? "day"
    var body: some Scene {
        WindowGroup {
            S04Root(scenario: scenario)
                .sportiliTheme()
                .preferredColorScheme(scenario.contains("dark") ? .dark : .light)
                .environment(\.dynamicTypeSize, scenario.contains("large") ? .accessibility3 : .large)
        }
    }
}

private struct S04Root: View {
    let scenario: String
    private let names = ["Plank", "Distensioni su panca inclinata con manubri e controllo della fase eccentrica", "Élite"]
    private var exercises: [Esercizio] {
        [
            Esercizio(id: "single", name: names[0], serie: "3 × 40 secondi", riposo: "1:30", notePT: "Mantieni il bacino stabile e respira durante tutta la serie."),
            Esercizio(id: "double", name: names.prefix(2).joined(separator: " + "), serie: "3 × 40 secondi + 4 × 8–10", riposo: "1:30", notePT: "Esegui entrambe le parti, poi recupera."),
            Esercizio(id: "triple", name: names.joined(separator: " + "), serie: "3 × 40 secondi + 4 × 8–10 + 3 × 12", riposo: "1:30", notePT: "Esegui tutte e tre le parti, poi recupera."),
            Esercizio(id: "long", name: names[1], serie: "4 × 8–10", riposo: "1:30", notePT: "Controlla la fase eccentrica.")
        ]
    }
    private var model: ExerciseDetailViewModel {
        ExerciseDetailViewModel(userCode: "", autoObserve: false, initialData: [
            "plank": UserExerciseData(noteUtente: "Nota della parte 1", weightLogs: ["p1": WeightLog(id: "p1", timestamp: 1_700_000_000_000, weight: 10)]),
            ExerciseDetailViewModel.makeExerciseKey(from: names[1]): UserExerciseData(noteUtente: "Nota della parte 2", weightLogs: ["p2": WeightLog(id: "p2", timestamp: 1_700_000_000_000, weight: 20)]),
            "lite": UserExerciseData(noteUtente: "Nota della parte 3 · chiave legacy", weightLogs: ["p3": WeightLog(id: "p3", timestamp: 1_700_000_000_000, weight: 30)])
        ])
    }
    private func loader() -> ImageLoader {
        let loader = ImageLoader()
        if scenario.contains("success") {
            loader.image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 500)).image { context in
                UIColor(red: 242/255, green: 229/255, blue: 218/255, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 800, height: 500))
                UIColor(red: 155/255, green: 74/255, blue: 0, alpha: 1).setFill()
                context.fill(CGRect(x: 240, y: 232, width: 260, height: 36))
                context.fill(CGRect(x: 210, y: 165, width: 40, height: 170))
                context.fill(CGRect(x: 490, y: 165, width: 40, height: 170))
            }
        } else if !scenario.contains("loading") {
            loader.error = NSError(domain: "local-image", code: 1)
        }
        return loader
    }
    var body: some View {
        NavigationStack {
            if scenario.hasPrefix("day") {
                DayView(day: Giorno(id: "day-z", name: "Giorno A · Spinta", gruppiMuscolari: [
                    GruppoMuscolare(id: "group-a", nome: "Petto e stabilità", esercizi: exercises)
                ]), detailViewModel: model, imageLoaderFactory: loader, autoLoadImages: false)
            } else {
                let exercise = exercises[scenario.hasPrefix("single") ? 0 : scenario.hasPrefix("double") ? 1 : scenario.hasPrefix("long") ? 3 : 2]
                EsercizioView(giornoId: "day-z", gruppoId: "group-a", esercizioId: exercise.id,
                    esercizio: exercise, userCode: "", viewModel: model, imageLoader: loader(), autoLoadImage: false)
            }
        }
    }
}
