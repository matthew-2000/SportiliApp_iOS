//
//  EsercizioView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI
import AVFoundation
import UIKit
import SwiftToast
import Charts

struct UniformLog: Identifiable {
    let id: Int
    let index: Int
    let date: Date
    let weight: Double
}

private enum WeightDialogMode: Equatable {
    case hidden
    case create
    case edit(WeightLog)
}

private struct WeightDeletionContext: Identifiable {
    let id = UUID()
    let record: WeightLog
    let exerciseKey: String
}

private struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct EsercizioView: View {

    var giornoId: String
    var gruppoId: String
    var esercizioId: String
    var esercizio: Esercizio

    @State private var selectedPartIndex = 0
    @State private var weightDialogMode: WeightDialogMode = .hidden
    @State private var weightInput: String = ""
    @State private var dialogExerciseKey: String
    @State private var noteInput: String
    @State private var lastSyncedNote: String
    @State private var lastSyncedNoteKey: String
    @State private var showTimerSheet = false
    @State private var showFullScreenImage = false
    @State private var isToastPresented = false
    @State private var toastMessage = ""
    @State private var toastColor: Color = .green
    @State private var errorAlert: ErrorAlert?
    @State private var deletionContext: WeightDeletionContext?

    @StateObject var imageLoader = ImageLoader()
    @StateObject private var viewModel: ExerciseDetailViewModel

    init(giornoId: String, gruppoId: String, esercizioId: String, esercizio: Esercizio) {
        self.giornoId = giornoId
        self.gruppoId = gruppoId
        self.esercizioId = esercizioId
        self.esercizio = esercizio

        let code = UserDefaults.standard.string(forKey: "code") ?? ""
        _viewModel = StateObject(wrappedValue: ExerciseDetailViewModel(userCode: code))

        let initialPartName = EsercizioView.primaryExerciseName(from: esercizio.name)
        let initialKey = ExerciseDetailViewModel.makeExerciseKey(from: initialPartName)

        _dialogExerciseKey = State(initialValue: initialKey)
        let initialNote = esercizio.noteUtente ?? ""
        _noteInput = State(initialValue: initialNote)
        _lastSyncedNote = State(initialValue: initialNote)
        _lastSyncedNoteKey = State(initialValue: initialKey)
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    private static let summaryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let sheetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    private static let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        let parts = Self.exerciseParts(from: esercizio.name)
        let seriesParts = Self.seriesParts(from: esercizio.serie)
        let currentIndex = min(selectedPartIndex, max(parts.count - 1, 0))
        let currentPartName = Self.partName(at: currentIndex, from: parts, fallback: esercizio.name)
        let currentKey = ExerciseDetailViewModel.makeExerciseKey(from: currentPartName)
        let currentData = viewModel.data(for: currentKey)
        let sortedLogs = currentData?.sortedWeightLogs ?? []
        let recentLogs = Array(sortedLogs.suffix(10))
        let latestRecord = sortedLogs.last
        let savedNote = currentData?.noteUtente ?? ""
        let isNoteDirty = noteInput != savedNote
        let selectedSerie = Self.serie(for: currentIndex, parts: parts, seriesParts: seriesParts, fallback: esercizio.serie)
        let canManageData = !viewModel.userCode.isEmpty

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // Immagine esercizio
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { showFullScreenImage.toggle() }
                        .fullScreenCover(isPresented: $showFullScreenImage) {
                            FullScreenImageView(image: image)
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 160)
                        if imageLoader.error != nil {
                            Text("Immagine non disponibile")
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        }
                    }
                    .onTapGesture { showFullScreenImage = false }
                }

                if parts.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Seleziona esercizio")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Picker("Esercizio", selection: $selectedPartIndex) {
                            ForEach(parts.indices, id: \.self) { index in
                                Text(parts[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedSerie)
                        .montserrat(size: 25)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    if let riposo = esercizio.riposo, !riposo.isEmpty {
                        Text("\(riposo) recupero")
                            .montserrat(size: 18)
                            .foregroundColor(.secondary)
                    }
                }

                if let notePT = esercizio.notePT, !notePT.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note PT")
                            .font(.headline)
                        Text(notePT)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Andamento peso")
                        .font(.headline)

                    if recentLogs.isEmpty {
                        Text("Nessun peso registrato")
                            .foregroundColor(.secondary)
                            .font(.body)
                    } else {
                        let chartData = recentLogs.enumerated().map { index, log in
                            UniformLog(id: index, index: index, date: log.date, weight: log.weight)
                        }
                        WeightChartView(data: chartData, dateFormatter: Self.logDateFormatter)
                            .frame(minHeight: 220)
                    }

                    if let record = latestRecord {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ultimo peso registrato")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(Self.summaryDateFormatter.string(from: record.date)) • \(formattedWeight(record.weight)) kg")
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                Button {
                                    dialogExerciseKey = currentKey
                                    weightDialogMode = .edit(record)
                                    weightInput = editingString(for: record.weight)
                                } label: {
                                    Text("Modifica")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManageData)

                                Button(role: .destructive) {
                                    deletionContext = WeightDeletionContext(record: record, exerciseKey: currentKey)
                                } label: {
                                    Text("Elimina")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManageData)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        dialogExerciseKey = currentKey
                        weightDialogMode = .create
                        weightInput = ""
                    } label: {
                        Label("Registra Peso", systemImage: "chart.xyaxis.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canManageData)

                    if let riposo = esercizio.riposo, !riposo.isEmpty {
                        Button {
                            showTimerSheet.toggle()
                        } label: {
                            Label("Avvia Timer di Recupero", systemImage: "timer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Note")
                        .font(.headline)

                    ZStack(alignment: .topLeading) {
                        if noteInput.isEmpty {
                            Text("Aggiungi una nota")
                                .foregroundColor(.secondary)
                                .padding(.top, 12)
                                .padding(.leading, 8)
                        }
                        TextEditor(text: $noteInput)
                            .frame(minHeight: 120)
                            .padding(4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack(spacing: 12) {
                        Button {
                            saveNote(for: currentKey)
                        } label: {
                            Text("Salva nota")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!isNoteDirty || !canManageData)

                        Button {
                            noteInput = savedNote
                        } label: {
                            Text("Annulla")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(!isNoteDirty)
                    }

                    if !savedNote.isEmpty {
                        Button(role: .destructive) {
                            removeNote(for: currentKey)
                        } label: {
                            Text("Rimuovi nota")
                        }
                        .disabled(!canManageData)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(esercizio.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: weightSheetBinding) {
            WeightEntrySheet(
                mode: weightDialogMode,
                weightInput: $weightInput,
                onConfirm: handleWeightConfirm,
                onCancel: dismissWeightSheet
            )
        }
        .sheet(isPresented: $showTimerSheet) {
            TimerSheet(riposo: esercizio.riposo ?? "")
        }
        .toast(
            isPresented: $isToastPresented,
            message: toastMessage,
            duration: 2.0,
            backgroundColor: toastColor,
            textColor: .white,
            font: .callout,
            position: .bottom,
            animationStyle: .slide
        )
        .alert(item: $deletionContext) { context in
            Alert(
                title: Text("Elimina peso"),
                message: Text("Vuoi eliminare il peso registrato il \(Self.summaryDateFormatter.string(from: context.record.date))?"),
                primaryButton: .destructive(Text("Elimina")) {
                    handleDeletion(context: context)
                },
                secondaryButton: .cancel {
                    deletionContext = nil
                }
            )
        }
        .alert(item: $errorAlert) { alert in
            Alert(
                title: Text("Errore"),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(esercizio.name).png"
            imageLoader.loadImage(from: storagePath)
        }
        .onReceive(viewModel.$exerciseData) { _ in
            syncNote(for: currentKey, force: false)
        }
        .onChange(of: selectedPartIndex) { newIndex in
            let newPartName = Self.partName(at: newIndex, from: parts, fallback: esercizio.name)
            let newKey = ExerciseDetailViewModel.makeExerciseKey(from: newPartName)
            dialogExerciseKey = newKey
            syncNote(for: newKey, force: true)
            weightDialogMode = .hidden
            weightInput = ""
            deletionContext = nil
        }
    }

    private var weightSheetBinding: Binding<Bool> {
        Binding(
            get: { weightDialogMode != .hidden },
            set: { if !$0 { dismissWeightSheet() } }
        )
    }

    private func formattedWeight(_ value: Double) -> String {
        Self.weightFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func editingString(for weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.2f", weight)
    }

    private func showToast(message: String, color: Color = .green) {
        toastMessage = message
        toastColor = color
        isToastPresented = true
    }

    private func showError(_ message: String) {
        errorAlert = ErrorAlert(message: message)
    }

    private func dismissWeightSheet() {
        weightDialogMode = .hidden
        weightInput = ""
    }

    private func handleWeightConfirm() {
        let normalized = weightInput.replacingOccurrences(of: ",", with: ".")
        guard let weightValue = Double(normalized), weightValue > 0 else {
            showError("Inserisci un peso valido")
            return
        }

        let key = dialogExerciseKey

        switch weightDialogMode {
        case .create:
            viewModel.addWeightEntry(for: key, weight: weightValue) { result in
                switch result {
                case .success:
                    showToast(message: "Peso salvato")
                    dismissWeightSheet()
                case .failure(let message):
                    showError(message.errorDescription ?? "Errore sconosciuto")
                }
            }
        case .edit(let record):
            viewModel.updateWeightEntry(for: key, entryId: record.id, weight: weightValue) { result in
                switch result {
                case .success:
                    showToast(message: "Peso aggiornato")
                    dismissWeightSheet()
                case .failure(let message):
                    showError(message.errorDescription ?? "Errore sconosciuto")
                }
            }
        case .hidden:
            break
        }
    }

    private func handleDeletion(context: WeightDeletionContext) {
        viewModel.deleteWeightEntry(for: context.exerciseKey, entryId: context.record.id) { result in
            switch result {
            case .success:
                showToast(message: "Peso eliminato")
                deletionContext = nil
            case .failure(let message):
                deletionContext = nil
                showError(message.errorDescription ?? "Errore sconosciuto")
            }
        }
    }

    private func saveNote(for key: String) {
        let trimmed = noteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeNote(for: key)
            return
        }
        viewModel.updateUserNote(for: key, note: trimmed) { result in
            switch result {
            case .success:
                let sanitized = trimmed.isEmpty ? "" : trimmed
                noteInput = sanitized
                lastSyncedNote = sanitized
                lastSyncedNoteKey = key
                showToast(message: "Nota salvata")
            case .failure(let message):
                showError(message.errorDescription ?? "Errore sconosciuto")
            }
        }
    }

    private func removeNote(for key: String) {
        viewModel.updateUserNote(for: key, note: nil) { result in
            switch result {
            case .success:
                noteInput = ""
                lastSyncedNote = ""
                lastSyncedNoteKey = key
                showToast(message: "Nota rimossa", color: .orange)
            case .failure(let message):
                showError(message.errorDescription ?? "Errore sconosciuto")
            }
        }
    }

    private func syncNote(for key: String, force: Bool) {
        let remoteNote = viewModel.data(for: key)?.noteUtente ?? ""
        if force {
            noteInput = remoteNote
            lastSyncedNote = remoteNote
            lastSyncedNoteKey = key
        } else {
            guard key == lastSyncedNoteKey else { return }
            if noteInput == lastSyncedNote {
                noteInput = remoteNote
                lastSyncedNote = remoteNote
            }
        }
    }

    private static func exerciseParts(from name: String) -> [String] {
        let components = name.split(separator: "+").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !components.isEmpty {
            return components
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }

    private static func primaryExerciseName(from name: String) -> String {
        exerciseParts(from: name).first ?? name
    }

    private static func seriesParts(from serie: String) -> [String] {
        serie.split(separator: "+").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func partName(at index: Int, from parts: [String], fallback: String) -> String {
        guard index >= 0 && index < parts.count else {
            return fallback
        }
        return parts[index]
    }

    private static func serie(for index: Int, parts: [String], seriesParts: [String], fallback: String) -> String {
        if seriesParts.count == parts.count, index < seriesParts.count {
            return seriesParts[index]
        }
        if index < seriesParts.count {
            return seriesParts[index]
        }
        return fallback
    }
}

private struct WeightEntrySheet: View {
    let mode: WeightDialogMode
    @Binding var weightInput: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var record: WeightLog? {
        if case let .edit(log) = mode {
            return log
        }
        return nil
    }

    private var title: String {
        switch mode {
        case .create:
            return "Registra peso"
        case .edit:
            return "Modifica peso"
        case .hidden:
            return "Peso"
        }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Peso (kg)")
                    .font(.headline)
                TextField("Peso (kg)", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                if let record {
                    Text("Ultimo aggiornamento: \(EsercizioView.sheetDateFormatter.string(from: record.date))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("Data: \(EsercizioView.sheetDateFormatter.string(from: Date()))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: onConfirm)
                }
            }
        }
    }
}

struct WeightChartView: View {
    let data: [UniformLog]
    let dateFormatter: DateFormatter

    private var lineGradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [Color.blue, Color.purple],
            startPoint: .leading,
            endPoint: .trailing
        ))
    }

    var body: some View {
        Chart {
            ForEach(data) { item in
                LineMark(
                    x: .value("Index", item.index),
                    y: .value("Peso", item.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(lineGradient)
            }

            ForEach(data) { item in
                PointMark(
                    x: .value("Index", item.index),
                    y: .value("Peso", item.weight)
                )
                .symbolSize(60)
                .foregroundStyle(.accent)
                .annotation(position: .top) {
                    Text("\(formatWeight(item.weight)) kg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: data.map { $0.index }) { value in
                if let idx = value.as(Int.self), let item = data.first(where: { $0.index == idx }) {
                    AxisValueLabel {
                        Text(dateFormatter.string(from: item.date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) { return String(format: "%.0f", weight) }
        return String(format: "%.1f", weight)
    }
}

struct FullScreenImageView: View {
    var image: UIImage
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    })
                }
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

struct TimerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var timeRemaining: Int
    @State private var totalTime: Int
    @State private var timerIsActive = false
    @State private var timerPaused = false
    @State private var timer: Timer?

    @State private var audioPlayer: AVAudioPlayer?

    init(riposo: String) {
        let parsedTime = TimerSheet.parseRiposo(riposo)
        _timeRemaining = State(initialValue: parsedTime)
        _totalTime = State(initialValue: parsedTime)
    }

    var body: some View {
        NavigationView {
            VStack {
                Spacer()

                Text("Tempo di recupero")
                    .montserrat(size: 30)
                    .bold()
                    .padding(.bottom, 40)

                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(Double(timeRemaining) / Double(totalTime)))
                        .stroke(Color.accentColor, lineWidth: 10)
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))

                    Text(formatTime(timeRemaining))
                        .montserrat(size: 80)
                        .bold()
                }
                .padding()

                Spacer()

                HStack {
                    if timerIsActive {
                        Button(action: stopTimer) {
                            HStack {
                                Image(systemName: "stop.circle")
                                Text("Stop")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else if timerPaused {
                        Button(action: startTimer) {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Riprendi")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button(action: startTimer) {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Inizia")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Chiudi") {
                presentationMode.wrappedValue.dismiss()
            })
            .interactiveDismissDisabled(true)
        }
    }

    func startTimer() {
        if !timerIsActive {
            timerIsActive = true
            timerPaused = false
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer?.invalidate()
                    timerIsActive = false
                    playSound()
                    triggerVibration()
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timerIsActive = false
        timerPaused = true
    }

    func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func parseRiposo(_ riposo: String) -> Int {
        let components = riposo.split(separator: "'")
        if components.count == 2 {
            let minutes = Int(components[0]) ?? 0
            let seconds = Int(components[1].replacingOccurrences(of: "\"", with: "")) ?? 0
            return minutes * 60 + seconds
        }
        return 0
    }

    func playSound() {
        AudioServicesPlaySystemSound(SystemSoundID(1022))
    }

    func triggerVibration() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
