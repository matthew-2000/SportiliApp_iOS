// Test-only entry point, substituted into a temporary project by
// run_exercise_previews.py. Firebase is never configured.
import SwiftUI
import UIKit

@main
struct ExercisePreviewHost: App {
    private let scenario: String

    init() {
        scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--scenario=") }
            .map { String($0.dropFirst("--scenario=".count)) } ?? "exercise"
        precondition([
            "day", "exercise", "fullscreen", "empty", "history", "timer", "weight-keyboard",
            "saving", "font", "dark"
        ].contains(scenario))
    }

    var body: some Scene {
        WindowGroup {
            ExercisePreviewRoot(scenario: scenario)
                .preferredColorScheme(scenario == "dark" ? .dark : .light)
                .environment(\.dynamicTypeSize, scenario == "font" ? .accessibility3 : .large)
                .montserrat(size: 17)
        }
    }
}

private struct ExercisePreviewRoot: View {
    let scenario: String
    @State private var weightInput = "47,5"

    var body: some View {
        Group {
            switch scenario {
            case "day":
                NavigationStack { DayView(day: PreviewData.longNamesDay) }
            case "history":
                NavigationStack {
                    List {
                        WeightProgressCard(data: chartData, dateFormatter: EsercizioView.summaryDateFormatter)
                    }
                    .navigationTitle("Progressi")
                }
            case "empty":
                NavigationStack {
                    List {
                        EmptyStateRow(
                            title: "Nessun peso registrato",
                            message: "Registra il primo peso per iniziare a vedere i progressi.",
                            systemImage: "scalemass"
                        )
                    }
                    .navigationTitle("Progressi")
                }
            case "timer":
                TimerSheet(riposo: "1:30")
            case "fullscreen":
                FullScreenImageView(image: previewImage)
            case "weight-keyboard":
                WeightEntrySheet(
                    mode: .create,
                    weightInput: $weightInput,
                    isSaving: false,
                    onConfirm: {},
                    onCancel: {}
                )
            case "saving":
                WeightEntrySheet(
                    mode: .edit(PreviewData.weightLogs[0]),
                    weightInput: $weightInput,
                    isSaving: true,
                    onConfirm: {},
                    onCancel: {}
                )
            default:
                NavigationStack {
                    exerciseView
                }
            }
        }
    }

    private var exerciseView: some View {
        let exercise = PreviewData.longSupersetExercise
        let firstPart = exercise.name.split(separator: "+").first.map(String.init) ?? exercise.name
        let key = ExerciseDetailViewModel.makeExerciseKey(from: firstPart)
        let logs = Dictionary(uniqueKeysWithValues: PreviewData.weightLogs.map { ($0.id, $0) })
        let model = ExerciseDetailViewModel(
            userCode: "preview",
            autoObserve: false,
            initialData: [key: UserExerciseData(noteUtente: exercise.noteUtente, weightLogs: logs)]
        )
        let loader = ImageLoader()
        if scenario == "exercise" {
            loader.image = previewImage
        } else {
            loader.error = NSError(domain: "preview", code: 1)
        }
        return EsercizioView(
            giornoId: PreviewData.longNamesDay.id,
            gruppoId: PreviewData.longNamesDay.gruppiMuscolari[0].id,
            esercizioId: exercise.id,
            esercizio: exercise,
            userCode: "preview",
            viewModel: model,
            imageLoader: loader,
            autoLoadImage: false
        )
    }

    private var chartData: [UniformLog] {
        PreviewData.weightLogs.enumerated().map { index, log in
            UniformLog(id: index, index: index, date: log.date, weight: log.weight)
        }
    }

    private var previewImage: UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 500))
        return renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 500))
            let configuration = UIImage.SymbolConfiguration(pointSize: 180, weight: .semibold)
            let symbol = UIImage(systemName: "figure.strengthtraining.traditional", withConfiguration: configuration)
            symbol?.withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 310, y: 160, width: 180, height: 180))
        }
    }
}
