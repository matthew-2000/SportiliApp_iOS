// Temporary, Firebase-free host for the real S05 components and detail handlers.
import SwiftUI
import UIKit

private let s05Note = (1...8).map { "Nota \($0): mantieni il controllo del movimento e registra le sensazioni della serie." }.joined(separator: "\n")
private func s05Logs(_ count: Int) -> [WeightLog] {
    (0..<count).map { WeightLog(id: "log-\($0)", timestamp: 1_700_000_000_000 + Double($0 * $0) * 86_400_000,
                              weight: 20 + Double($0) * 2.5) }
}

@main
struct S05PreviewHost: App {
    private let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
        .map { String($0.dropFirst("--scenario=".count)) } ?? "detail"
    var body: some Scene {
        WindowGroup {
            S05Root(scenario: scenario)
                .preferredColorScheme(scenario.contains("dark") ? .dark : .light)
                .environment(\.dynamicTypeSize, scenario.contains("large") ? .accessibility3 : .large)
                .sportiliTheme()
        }
    }
}

private struct S05Root: View {
    let scenario: String
    @State private var input: String
    @State private var note: String
    @State private var savedNote: String
    @State private var saving = false
    @State private var error: String?
    @State private var presented = true
    @StateObject private var model: ExerciseDetailViewModel
    private let loader = ImageLoader()
    init(scenario: String) {
        self.scenario = scenario
        _input = State(initialValue: scenario.contains("invalid") ? "0" : scenario.contains("point") ? "47.5" : "47,5")
        let value = scenario.contains("empty") ? "" : s05Note
        _note = State(initialValue: value)
        _savedNote = State(initialValue: value)
        _saving = State(initialValue: scenario.contains("pending"))
        _error = State(initialValue: scenario.contains("failure") ? "Salvataggio non riuscito. Riprova." : nil)
        let logs = Dictionary(uniqueKeysWithValues: s05Logs(12).map { ($0.id, $0) })
        _model = StateObject(wrappedValue: ExerciseDetailViewModel(userCode: "local-fixture", autoObserve: false,
            initialData: ["plank": UserExerciseData(noteUtente: s05Note, weightLogs: logs),
                          "lite": UserExerciseData(noteUtente: "Nota della terza parte · legacy", weightLogs: ["p3": WeightLog(id: "p3", timestamp: 1_700_000_000_000, weight: 30)]),
                          "panca": UserExerciseData(noteUtente: "Nota della seconda parte")]))
        loader.error = NSError(domain: "local-fixture", code: 1)
    }
    var body: some View {
        if scenario.hasPrefix("history") {
            let count = scenario.split(separator: "-").dropFirst().first.flatMap { Int($0) } ?? 12
            NavigationStack {
                List {
                    Button("Registra peso") {}
                    if count == 0 { EmptyStateRow(title: "Nessun peso registrato", message: "Registra il primo peso per iniziare a seguire i progressi.", systemImage: "scalemass") }
                    else { WeightProgressCard(data: s05Logs(count).enumerated().map { UniformLog(id: $0.offset, index: $0.offset + 1, date: $0.element.date, weight: $0.element.weight) }, dateFormatter: EsercizioView.summaryDateFormatter) }
                }.navigationTitle("Pesi e progressi")
            }
        } else if scenario.hasPrefix("weight") {
            Color.clear.sheet(isPresented: $presented) {
                WeightEntrySheet(mode: .create, weightInput: $input, isSaving: saving, errorMessage: error,
                    onConfirm: {
                        guard !saving else { return }
                        if parsedWeightInput(input) == nil { error = "Inserisci un peso maggiore di zero, con virgola o punto." }
                        else { error = "Salvataggio non riuscito. Riprova." }
                    }, onCancel: { presented = false })
                    .environment(\.dynamicTypeSize, scenario.contains("large") ? .accessibility3 : .large)
            }
        } else if scenario.hasPrefix("notes") {
            NavigationStack {
                List { PersonalNotesCard(text: savedNote, isDirty: note != savedNote, onTap: { presented = true }) }
                    .navigationTitle("Note personali")
            }.sheet(isPresented: $presented) {
                NotesEditorSheet(title: "Note personali", text: $note, savedText: savedNote,
                    canManage: true, isSaving: saving, isDirty: note != savedNote, errorMessage: error,
                    onSave: { error = "Salvataggio non riuscito. Riprova." },
                    onRevert: { note = savedNote }, onDelete: { error = "Salvataggio non riuscito. Riprova." })
                    .environment(\.dynamicTypeSize, scenario.contains("large") ? .accessibility3 : .large)
            }
        } else if scenario.hasPrefix("timer") {
            Color.clear.sheet(isPresented: $presented) { TimerSheet(riposo: scenario.contains("no-rest") ? "" : "1:30").environment(\.dynamicTypeSize, scenario.contains("large") ? .accessibility3 : .large) }
        } else {
            let exercise = Esercizio(id: "s05", name: scenario.contains("triple") ? "Plank + Panca + Élite" : "Plank",
                serie: "3 × 40 secondi", riposo: "1:30", notePT: "Indicazioni del trainer: mantieni il bacino stabile.")
            NavigationStack {
                EsercizioView(giornoId: "day", gruppoId: "group", esercizioId: "s05", esercizio: exercise,
                    userCode: "local-fixture", viewModel: model, imageLoader: loader, autoLoadImage: false,
                    actions: ExerciseDetailActions(addWeight: { key, weight, completion in
                        let log = WeightLog(id: "local-new", timestamp: 1_790_000_000_000, weight: weight)
                        model.applyS05Fixture(key, note: nil, entry: log); completion(.success(log))
                    }, updateWeight: { key, id, weight, completion in
                        let log = WeightLog(id: id, timestamp: 1_790_000_000_000, weight: weight)
                        model.applyS05Fixture(key, note: nil, entry: log); completion(.success(log))
                    }, updateNote: { key, note, completion in
                        model.applyS05Fixture(key, note: note); completion(.success(()))
                    }))
            }
        }
    }
}
