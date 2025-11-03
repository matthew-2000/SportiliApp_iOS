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
        let currentIndex = min(selectedPartIndex, max(parts.count - 1, 0))
        let currentPartName = Self.partName(at: currentIndex, from: parts, fallback: esercizio.name)
        let currentKey = ExerciseDetailViewModel.makeExerciseKey(from: currentPartName)
        let currentData = viewModel.data(for: currentKey)
        let sortedLogs = currentData?.sortedWeightLogs ?? []
        let recentLogs = Array(sortedLogs.suffix(10))
        let latestRecord = sortedLogs.last
        let savedNote = currentData?.noteUtente ?? ""
        let isNoteDirty = noteInput != savedNote
        // SERIE: ora mostriamo sempre quella completa
        let fullSerie = esercizio.serie
        let canManageData = !viewModel.userCode.isEmpty

        let heroSubtitle = parts.count > 1 ? currentPartName : nil

        let heroState: ExerciseHeroState
        if let image = imageLoader.image {
            heroState = .loaded(image)
        } else if imageLoader.error != nil {
            heroState = .failed
        } else {
            heroState = .loading
        }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                ExerciseHeroView(
                    state: heroState,
                    title: esercizio.name,
                    subtitle: heroSubtitle,
                    onTap: { showFullScreenImage = true }
                )
                .padding(.top, 8)

                if parts.count > 1 {
                    ExerciseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Variazioni esercizio", systemImage: "square.grid.2x2")
                                .font(.headline)
                            Picker("Esercizio", selection: $selectedPartIndex) {
                                ForEach(parts.indices, id: \.self) { index in
                                    Text(parts[index]).tag(index)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                ExerciseCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Serie", systemImage: "figure.strengthtraining.functional")
                            .font(.headline)
                        // Mostra sempre la serie completa
                        Text(fullSerie)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let riposo = esercizio.riposo, !riposo.isEmpty {
                            Divider()
                            Label("\(riposo) recupero", systemImage: "timer")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let notePT = esercizio.notePT,
                           !notePT.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Note del coach", systemImage: "person.text.rectangle")
                                    .font(.headline)
                                Text(notePT)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                ExerciseCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Andamento peso", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)

                        if recentLogs.isEmpty {
                            Text("Registra il tuo primo peso per visualizzare i progressi.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            let chartData = recentLogs.enumerated().map { index, log in
                                UniformLog(id: index, index: index, date: log.date, weight: log.weight)
                            }
                            WeightChartView(data: chartData, dateFormatter: Self.logDateFormatter)
                                .frame(minHeight: 220)
                        }

                        if let record = latestRecord {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ultimo peso registrato")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(Self.summaryDateFormatter.string(from: record.date)) • \(formattedWeight(record.weight)) kg")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    dialogExerciseKey = currentKey
                                    weightDialogMode = .edit(record)
                                    weightInput = editingString(for: record.weight)
                                } label: {
                                    Label("Modifica", systemImage: "pencil")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .disabled(!canManageData)

                                Button(role: .destructive) {
                                    deletionContext = WeightDeletionContext(record: record, exerciseKey: currentKey)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .disabled(!canManageData)
                            }
                        }
                    }
                }

                ExerciseCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Azioni rapide", systemImage: "bolt.fill")
                            .font(.headline)

                        Button {
                            dialogExerciseKey = currentKey
                            weightDialogMode = .create
                            weightInput = ""
                        } label: {
                            Label("Registra peso", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canManageData)

                        if let riposo = esercizio.riposo, !riposo.isEmpty {
                            Button {
                                showTimerSheet.toggle()
                            } label: {
                                Label("Avvia timer di recupero", systemImage: "timer")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                }

                // --- NOTE PERSONALI (nuova UI) ---
                ExerciseCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Note personali", systemImage: "square.and.pencil")
                                .font(.headline)
                            Spacer()
                            if !savedNote.isEmpty {
                                Text("Salvata")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // TextEditor stile iOS
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemBackground))

                            TextEditor(text: $noteInput)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(minHeight: 120, maxHeight: 160)
                                .background(Color.clear)
                                .scrollContentBackground(.hidden)

                            if noteInput.isEmpty {
                                Text("Aggiungi una nota per questo esercizio…")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )

                        HStack(spacing: 10) {
                            Button {
                                saveNote(for: currentKey)
                            } label: {
                                Label("Salva", systemImage: "tray.and.arrow.down")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(!isNoteDirty || !canManageData)

                            Button {
                                noteInput = savedNote
                            } label: {
                                Text("Annulla")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isNoteDirty)

                            Spacer()

                            if !savedNote.isEmpty {
                                Button(role: .destructive) {
                                    removeNote(for: currentKey)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .disabled(!canManageData)
                            }
                        }

                        if !savedNote.isEmpty {
                            Text("Ultimo salvataggio collegato a: \(currentPartName)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(esercizio.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showFullScreenImage) {
            Group {
                if let image = imageLoader.image {
                    FullScreenImageView(image: image)
                }
            }
        }
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
        .confirmationDialog(
            "Elimina peso",
            isPresented: Binding(
                get: { deletionContext != nil },
                set: { if !$0 { deletionContext = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                if let ctx = deletionContext {
                    handleDeletion(context: ctx)
                }
                deletionContext = nil
            }

            Button("Annulla", role: .cancel) {
                deletionContext = nil
            }
        } message: {
            if let ctx = deletionContext {
                Text("Vuoi eliminare il peso registrato il \(Self.summaryDateFormatter.string(from: ctx.record.date))?")
            }
        }
        .alert(item: $errorAlert) { alert in
            Alert(
                title: Text("Errore"),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // carica immagine in base alla prima parte dell’esercizio
            let initialPartName = Self.primaryExerciseName(from: esercizio.name)
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(initialPartName).png"
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

            // cambia immagine in base alla variazione
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(newPartName).png"
            imageLoader.loadImage(from: storagePath)
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
        print("Elimina")
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

    private static func partName(at index: Int, from parts: [String], fallback: String) -> String {
        guard index >= 0 && index < parts.count else {
            return fallback
        }
        return parts[index]
    }
}

private enum ExerciseHeroState {
    case loading
    case failed
    case loaded(UIImage)
}

private struct ExerciseHeroView: View {
    let state: ExerciseHeroState
    let title: String
    let subtitle: String?
    let onTap: () -> Void

    var body: some View {
        ZStack {
            backgroundContent
            overlayContent
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            if case .loaded = state {
                onTap()
            }
        }
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)
    }

    @ViewBuilder
    private var backgroundContent: some View {
        switch state {
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        case .loading:
            LinearGradient(
                colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .failed:
            Color(.secondarySystemGroupedBackground)
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        switch state {
        case .loaded:
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(20)
        case .loading:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("Immagine non disponibile")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ExerciseCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
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
            Form {
                Section(header: Text("Peso")) {
                    TextField("Peso (kg)", text: $weightInput)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Dettagli")) {
                    if let record {
                        HStack {
                            Label("Ultimo aggiornamento", systemImage: "clock")
                            Spacer()
                            Text(EsercizioView.sheetDateFormatter.string(from: record.date))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Label("Data", systemImage: "calendar")
                            Spacer()
                            Text(EsercizioView.sheetDateFormatter.string(from: Date()))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
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

                HStack(spacing: 16) {
                    if timerIsActive {
                        Button(action: pauseTimer) {
                            Label("Pausa", systemImage: "pause.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: resetTimer) {
                            Label("Reset", systemImage: "gobackward")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Button(action: startTimer) {
                            Label(timerPaused ? "Riprendi" : "Inizia", systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: resetTimer) {
                            Label("Reset", systemImage: "gobackward")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(timeRemaining == totalTime)
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
        guard !timerIsActive else { return }

        if timeRemaining == 0 {
            timeRemaining = totalTime
        }

        timerIsActive = true
        timerPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                timer = nil
                timerIsActive = false
                timerPaused = false
                timeRemaining = totalTime
                playSound()
                triggerVibration()
            }
        }
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        timerIsActive = false
        timerPaused = true
    }

    func resetTimer() {
        timer?.invalidate()
        timer = nil
        timeRemaining = totalTime
        timerIsActive = false
        timerPaused = false
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
