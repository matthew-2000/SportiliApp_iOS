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

// MARK: - Models (UI)

struct UniformLog: Identifiable {
    let id: Int
    let index: Int
    let date: Date
    let weight: Double
}

enum WeightDialogMode: Equatable {
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

// Feature-local callbacks; production delegates to the existing model.
struct ExerciseDetailActions {
    var addWeight: (String, Double, @escaping (Result<WeightLog, ExerciseDataError>) -> Void) -> Void
    var updateWeight: (String, String, Double, @escaping (Result<WeightLog, ExerciseDataError>) -> Void) -> Void
    var updateNote: (String, String?, @escaping (Result<Void, ExerciseDataError>) -> Void) -> Void
}

extension ExerciseDetailActions {
    init(model: ExerciseDetailViewModel) {
        addWeight = { model.addWeightEntry(for: $0, weight: $1, completion: $2) }
        updateWeight = { model.updateWeightEntry(for: $0, entryId: $1, weight: $2, completion: $3) }
        updateNote = { model.updateUserNote(for: $0, note: $1, completion: $2) }
    }
}

// Decimal input accepts either separator, never non-finite or scientific notation.
func parsedWeightInput(_ input: String) -> Double? {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.range(of: "^[0-9]+([.,][0-9]+)?$", options: .regularExpression) != nil,
          let weight = Double(value.replacingOccurrences(of: ",", with: ".")),
          weight.isFinite, weight > 0 else { return nil }
    return weight
}

// MARK: - Main View

struct EsercizioView: View {

    var giornoId: String
    var gruppoId: String
    var esercizioId: String
    var esercizio: Esercizio

    @State private var selectedPartIndex = 0

    // Peso
    @State private var weightDialogMode: WeightDialogMode = .hidden
    @State private var weightInput: String = ""
    @State private var dialogExerciseKey: String
    @State private var isWeightSaving = false
    @State private var weightError: String?

    // Note
    @State private var noteInput: String
    @State private var lastSyncedNote: String
    @State private var lastSyncedNoteKey: String
    @State private var showNotesSheet = false
    @State private var isNotesSaving = false
    @State private var noteError: String?

    // UI
    @State private var showTimerSheet = false
    @State private var showFullScreenImage = false
    @State private var isToastPresented = false
    @State private var toastMessage = ""
    @State private var toastColor: Color = .green
    @State private var errorAlert: ErrorAlert?
    @State private var deletionContext: WeightDeletionContext?

    @StateObject private var imageLoader: ImageLoader
    @StateObject private var viewModel: ExerciseDetailViewModel
    private let autoLoadImage: Bool
    private let actions: ExerciseDetailActions

    init(
        giornoId: String,
        gruppoId: String,
        esercizioId: String,
        esercizio: Esercizio,
        userCode: String? = nil,
        viewModel: ExerciseDetailViewModel? = nil,
        imageLoader: ImageLoader = ImageLoader(),
        autoLoadImage: Bool = true,
        actions: ExerciseDetailActions? = nil
    ) {
        self.giornoId = giornoId
        self.gruppoId = gruppoId
        self.esercizioId = esercizioId
        self.esercizio = esercizio
        self.autoLoadImage = autoLoadImage

        let resolvedCode = userCode ?? UserDefaults.standard.string(forKey: "code") ?? ""
        let resolvedViewModel = viewModel ?? ExerciseDetailViewModel(userCode: resolvedCode)
        self.actions = actions ?? ExerciseDetailActions(model: resolvedViewModel)
        _viewModel = StateObject(wrappedValue: resolvedViewModel)
        _imageLoader = StateObject(wrappedValue: imageLoader)

        let initialPartName = EsercizioView.primaryExerciseName(from: esercizio.name)
        let initialKey = resolvedViewModel.exerciseKey(from: initialPartName)
        _dialogExerciseKey = State(initialValue: initialKey)

        let initialNote = resolvedViewModel.data(for: initialKey)?.noteUtente ?? ""
        _noteInput = State(initialValue: initialNote)
        _lastSyncedNote = State(initialValue: initialNote)
        _lastSyncedNoteKey = State(initialValue: initialKey)
    }

    // MARK: - Formatters

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    static let summaryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "it_IT")
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

    // MARK: - Body

    var body: some View {
        let parts = Self.exerciseParts(from: esercizio.name)
        let currentIndex = min(selectedPartIndex, max(parts.count - 1, 0))
        let currentPartName = Self.partName(at: currentIndex, from: parts, fallback: esercizio.name)
        let currentKey = viewModel.exerciseKey(from: currentPartName)

        let currentData = viewModel.data(for: currentKey)
        let sortedLogs = currentData?.sortedWeightLogs ?? []
        let recentLogs = Array(sortedLogs.suffix(10))
        let savedNote = currentData?.noteUtente ?? ""
        let isNoteDirty = noteInput != savedNote
        let canManageData = !viewModel.userCode.isEmpty

        let heroState: ExerciseHeroState
        if let image = imageLoader.image {
            heroState = .loaded(image)
        } else if imageLoader.error != nil {
            heroState = .failed
        } else {
            heroState = .loading
        }

        return List {
            Section {
                if parts.count > 1 {
                    Label("Superset · \(parts.count) parti", systemImage: "link")
                        .font(SportiliTypography.label)
                        .foregroundStyle(SportiliPalette.primary)
                    Text("Esegui tutte le parti in combinazione.")
                        .font(SportiliTypography.bodySmall)
                        .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    ExerciseVariationPicker(parts: parts, selectedIndex: $selectedPartIndex)
                } else {
                    Text(currentPartName)
                        .font(SportiliTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(header: Text("Programma").font(SportiliTypography.label)) {
                PrescriptionCard(
                    serie: esercizio.serie,
                    riposo: esercizio.riposo,
                    onStartTimer: { showTimerSheet = true }
                )
            }

            Section {
                ExerciseHeroHeader(state: heroState, exerciseName: currentPartName,
                    onTap: { showFullScreenImage = true })
            }

            if let notePT = esercizio.notePT,
               !notePT.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section(header: Text("Indicazioni").font(SportiliTypography.label)) {
                    CoachNotesCard(text: notePT)
                }
            }

            Section(header: Text("Note personali").font(SportiliTypography.label)) {
                PersonalNotesCard(
                    text: savedNote,
                    isDirty: isNoteDirty,
                    onTap: {
                        isNotesSaving = false
                        noteError = nil
                        showNotesSheet = true
                    }
                )
                .id(currentKey)
            }

            Section(header: Text("Pesi e progressi").font(SportiliTypography.label)) {
                if let latest = sortedLogs.last {
                    WeightLogRow(date: Self.summaryDateFormatter.string(from: latest.date),
                                 weight: "Ultimo peso: \(formattedWeight(latest.weight)) kg")
                }
                Button {
                    dialogExerciseKey = currentKey
                    weightDialogMode = .create
                    weightInput = ""
                    weightError = nil
                } label: {
                    Label("Registra peso", systemImage: "plus.circle.fill")
                        .font(SportiliTypography.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(!canManageData)
                if recentLogs.isEmpty {
                    EmptyStateRow(
                        title: "Nessun peso registrato",
                        message: "Registra il primo peso per iniziare a vedere i progressi.",
                        systemImage: "scalemass"
                    )
                    .padding(.vertical, 6)
                } else {
                    let chartData = recentLogs.enumerated().map { idx, log in
                        UniformLog(id: idx, index: idx, date: log.date, weight: log.weight)
                    }
                    WeightProgressCard(data: chartData, dateFormatter: Self.logDateFormatter)
                }

                if !sortedLogs.isEmpty {
                    // lista pesi (più recente in alto)
                    ForEach(sortedLogs.reversed()) { log in
                        WeightLogRow(
                            date: Self.summaryDateFormatter.string(from: log.date),
                            weight: "\(formattedWeight(log.weight)) kg"
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletionContext = WeightDeletionContext(record: log, exerciseKey: currentKey)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                                    .montserrat(size: 17)
                            }

                            Button {
                                dialogExerciseKey = currentKey
                                weightDialogMode = .edit(log)
                                weightInput = editingString(for: log.weight)
                                weightError = nil
                            } label: {
                                Label("Modifica", systemImage: "pencil")
                                    .montserrat(size: 17)
                            }
                            .tint(.blue)
                        }
                        .disabled(!canManageData)
                    }
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
                isSaving: isWeightSaving,
                errorMessage: weightError,
                onConfirm: handleWeightConfirm,
                onCancel: dismissWeightSheet
            )
        }
        .sheet(isPresented: $showTimerSheet) {
            TimerSheet(riposo: esercizio.riposo ?? "")
        }
        .sheet(isPresented: $showNotesSheet) {
            NotesEditorSheet(
                title: "Note personali",
                text: $noteInput,
                savedText: savedNote,
                canManage: canManageData,
                isSaving: isNotesSaving,
                isDirty: isNoteDirty,
                errorMessage: noteError,
                onSave: {
                    guard !isNotesSaving else { return }
                    noteError = nil
                    isNotesSaving = true
                    saveNote(for: currentKey) { isSuccess in
                        isNotesSaving = false
                        if isSuccess {
                            showNotesSheet = false
                        }
                    }
                },
                onRevert: { noteInput = savedNote; noteError = nil },
                onDelete: {
                    guard !isNotesSaving else { return }
                    noteError = nil
                    isNotesSaving = true
                    removeNote(for: currentKey) { isSuccess in
                        isNotesSaving = false
                        if isSuccess {
                            showNotesSheet = false
                        }
                    }
                }
            )
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
            Text("Elimina peso"),
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
            .montserrat(size: 17)
            Button("Annulla", role: .cancel) {
                deletionContext = nil
            }
            .montserrat(size: 17)
        } message: {
            if let ctx = deletionContext {
                Text("Vuoi eliminare il peso registrato il \(Self.summaryDateFormatter.string(from: ctx.record.date))?")
                    .montserrat(size: 15)
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
            let initialPartName = Self.primaryExerciseName(from: esercizio.name)
            loadExerciseImage(for: initialPartName)
        }
        .onReceive(viewModel.$exerciseData) { data in
            // @Published emits before the model setter completes. Use the emitted snapshot.
            syncNote(for: currentKey, force: false, remoteNote: data[currentKey]?.noteUtente ?? "")
        }
        .onChange(of: selectedPartIndex) { newIndex in
            let newPartName = Self.partName(at: newIndex, from: parts, fallback: esercizio.name)
            let newKey = viewModel.exerciseKey(from: newPartName)

            dialogExerciseKey = newKey
            syncNote(for: newKey, force: true)

            // reset transiente
            weightDialogMode = .hidden
            weightInput = ""
            isWeightSaving = false
            weightError = nil
            noteError = nil
            deletionContext = nil

            loadExerciseImage(for: newPartName)
        }
    }

    // MARK: - Bindings

    private var weightSheetBinding: Binding<Bool> {
        Binding(
            get: { weightDialogMode != .hidden },
            set: { if !$0 { dismissWeightSheet() } }
        )
    }

    // MARK: - Helpers

    private func loadExerciseImage(for partName: String) {
        guard autoLoadImage, !PreviewContext.isPreview else { return }
        let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(partName).png"
        imageLoader.loadImage(from: storagePath)
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
        guard !isWeightSaving else { return }
        weightDialogMode = .hidden
        weightInput = ""
    }

    // MARK: - Weight actions

    private func handleWeightConfirm() {
        guard !isWeightSaving else { return }
        guard let weightValue = parsedWeightInput(weightInput) else {
            weightError = "Inserisci un peso maggiore di zero, con virgola o punto."
            return
        }
        weightError = nil

        let key = dialogExerciseKey
        isWeightSaving = true

        switch weightDialogMode {
        case .create:
            actions.addWeight(key, weightValue) { result in
                isWeightSaving = false
                switch result {
                case .success:
                    showToast(message: "Peso salvato")
                    dismissWeightSheet()
                case .failure(let message):
                    weightError = message.errorDescription ?? "Errore sconosciuto"
                }
            }

        case .edit(let record):
            actions.updateWeight(key, record.id, weightValue) { result in
                isWeightSaving = false
                switch result {
                case .success:
                    showToast(message: "Peso aggiornato")
                    dismissWeightSheet()
                case .failure(let message):
                    weightError = message.errorDescription ?? "Errore sconosciuto"
                }
            }

        case .hidden:
            isWeightSaving = false
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

    // MARK: - Notes actions (exerciseData is authoritative on both platforms)

    private func saveNote(for key: String, completion: @escaping (Bool) -> Void) {
        let trimmed = noteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        persistNote(trimmed.isEmpty ? nil : trimmed, for: key, completion: completion)
    }

    private func removeNote(for key: String, completion: @escaping (Bool) -> Void) {
        persistNote(nil, for: key, completion: completion)
    }

    private func persistNote(_ note: String?, for key: String, completion: @escaping (Bool) -> Void) {
        actions.updateNote(key, note) { result in
            switch result {
            case .success:
                noteInput = note ?? ""
                lastSyncedNote = note ?? ""
                lastSyncedNoteKey = key
                showToast(message: note == nil ? "Nota rimossa" : "Nota salvata",
                          color: note == nil ? .orange : .green)
                completion(true)
            case .failure(let message):
                noteError = message.errorDescription ?? "Errore sconosciuto"
                completion(false)
            }
        }
    }

    private func syncNote(for key: String, force: Bool, remoteNote: String? = nil) {
        let remoteNote = remoteNote ?? viewModel.data(for: key)?.noteUtente ?? ""
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

    // MARK: - Exercise name parts

    private static func exerciseParts(from name: String) -> [String] {
        let components = name
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !components.isEmpty { return components }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }

    private static func primaryExerciseName(from name: String) -> String {
        exerciseParts(from: name).first ?? name
    }

    private static func partName(at index: Int, from parts: [String], fallback: String) -> String {
        guard index >= 0 && index < parts.count else { return fallback }
        return parts[index]
    }
}

// MARK: - Hero

private enum ExerciseHeroState {
    case loading
    case failed
    case loaded(UIImage)
}

private struct ExerciseHeroHeader: View {
    let state: ExerciseHeroState
    let exerciseName: String
    let onTap: () -> Void

    var body: some View {
        Group {
            switch state {
            case .loaded(let image):
                Button(action: onTap) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipped()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apri immagine di \(exerciseName) a schermo intero")
            case .loading:
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SportiliPalette.surfaceMuted)
                    .overlay(ProgressView().accessibilityLabel("Caricamento immagine"))
                    .frame(height: 210)
            case .failed:
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SportiliPalette.surfaceMuted)
                    .overlay(
                        VStack(spacing: SportiliSpacing.compact) {
                            Image(systemName: "photo")
                                .font(.title2)
                            Text("Immagine non disponibile")
                                .font(SportiliTypography.bodySmall)
                        }
                        .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    )
                    .frame(height: 160)
                    .accessibilityElement(children: .combine)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
    }
}

// MARK: - Rows & Components (iOS 16 safe)

private struct ExerciseVariationPicker: View {
    let parts: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.small) {
            ForEach(parts.indices, id: \.self) { index in
                Button { selectedIndex = index } label: {
                    HStack(alignment: .top, spacing: SportiliSpacing.small) {
                        Image(systemName: selectedIndex == index ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Parte \(index + 1) di \(parts.count)" + (selectedIndex == index ? " · Attiva" : ""))
                                .font(SportiliTypography.labelSmall)
                            Text(parts[index])
                                .font(SportiliTypography.title)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(SportiliSpacing.small)
                    .foregroundStyle(selectedIndex == index ? SportiliPalette.primary : .primary)
                    .background(selectedIndex == index ? SportiliPalette.surfaceMuted : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: SportiliShape.control))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
            }
        }
    }
}

private struct PrescriptionCard: View {
    let serie: String
    let riposo: String?
    let onStartTimer: () -> Void

    private var hasRest: Bool {
        !(riposo?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.standard) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Serie e ripetizioni", systemImage: "figure.strengthtraining.functional")
                    .font(SportiliTypography.label)
                Text(serie)
                    .font(SportiliTypography.title)
                    .foregroundStyle(SportiliPalette.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasRest, let riposo {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label("Recupero", systemImage: "timer")
                        .font(SportiliTypography.label)
                    Text(riposo)
                        .font(SportiliTypography.title)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onStartTimer) {
                    HStack(alignment: .top, spacing: SportiliSpacing.compact) {
                        Image(systemName: "play.circle.fill")
                            .accessibilityHidden(true)
                        Text("Avvia timer di recupero")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(SportiliTypography.label)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .multilineTextAlignment(.leading)
                }
                .buttonStyle(.bordered)
                .tint(SportiliPalette.primary)
            } else {
                Button(action: onStartTimer) {
                    Text("Apri timer di recupero")
                        .font(SportiliTypography.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, SportiliSpacing.compact)
    }
}

private struct CoachNotesCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Note del trainer", systemImage: "person.text.rectangle")
                .font(SportiliTypography.label)
            Text(text)
                .font(SportiliTypography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, SportiliSpacing.compact)
    }
}

struct EmptyStateRow: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .montserrat(size: 17)
                .fontWeight(.semibold)
            Text(message)
                .montserrat(size: 15)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct WeightProgressCard: View {
    let data: [UniformLog]
    let dateFormatter: DateFormatter

    private static let valueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private var samples: [UniformLog] { Array(data.sorted { $0.date < $1.date }.suffix(10)) }

    private var summary: WeightProgressSummary? {
        guard let first = samples.first, let last = samples.last else { return nil }
        return WeightProgressSummary(
            latest: last.weight,
            delta: last.weight - first.weight,
            minimum: samples.map(\.weight).min() ?? last.weight,
            maximum: samples.map(\.weight).max() ?? last.weight
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.small) {
            Label("Ultime 10 registrazioni", systemImage: "chart.line.uptrend.xyaxis")
                .font(SportiliTypography.label)

            if let summary {
                VStack(alignment: .leading, spacing: SportiliSpacing.compact) {
                    Text("Ultimo peso: \(format(summary.latest)) kg")
                        .font(SportiliTypography.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Variazione tra primo e ultimo campione: \(signed(summary.delta)) kg · Minimo \(format(summary.minimum)) kg · Massimo \(format(summary.maximum)) kg")
                        .font(SportiliTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }

            WeightChartView(data: samples.enumerated().map { UniformLog(id: $0.offset, index: $0.offset + 1, date: $0.element.date, weight: $0.element.weight) }, dateFormatter: dateFormatter)
                .frame(height: 220)
                .accessibilityHidden(true)
            Text("Campioni in ordine di registrazione. Gli intervalli tra le date possono variare.")
                .font(SportiliTypography.bodySmall)
                .foregroundStyle(SportiliPalette.onSurfaceMuted)
            DisclosureGroup("Valori e date dei campioni") {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, log in
                    WeightLogRow(date: dateFormatter.string(from: log.date),
                                 weight: "Campione \(index + 1): \(format(log.weight)) kg")
                }
            }
            .font(SportiliTypography.bodySmall)
        }
        .padding(.vertical, 6)
    }

    private func format(_ value: Double) -> String {
        Self.valueFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func signed(_ value: Double) -> String {
        let formatted = format(abs(value))
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "−\(formatted)" }
        return formatted
    }
}

private struct WeightProgressSummary {
    let latest: Double
    let delta: Double
    let minimum: Double
    let maximum: Double
}

private struct WeightLogRow: View {
    let date: String
    let weight: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(weight)
                    .font(SportiliTypography.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text(date)
                    .font(SportiliTypography.bodySmall)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct PersonalNotesCard: View {
    let text: String
    let isDirty: Bool
    let onTap: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.small) {
            Text(text.isEmpty ? "Nessuna nota salvata" : text)
                .font(SportiliTypography.body)
                .foregroundStyle(text.isEmpty ? SportiliPalette.onSurfaceMuted : SportiliPalette.onSurface)
                .lineLimit(expanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
            if !text.isEmpty {
                Button(expanded ? "Riduci nota" : "Mostra tutta la nota") { expanded.toggle() }
                    .font(SportiliTypography.bodySmall)
            }
            if isDirty {
                Label("Modifiche non salvate", systemImage: "pencil")
                    .font(SportiliTypography.bodySmall)
            }
            Button(action: onTap) {
                Label(text.isEmpty ? "Aggiungi nota personale" : "Modifica nota personale", systemImage: "square.and.pencil")
                    .font(SportiliTypography.label)
            }
        }
        .buttonStyle(.borderless)
        .onChange(of: text) { _ in expanded = false }
    }
}

// MARK: - Notes Sheet (Pro)

struct NotesEditorSheet: View {
    let title: String
    @Binding var text: String
    let savedText: String
    let canManage: Bool
    let isSaving: Bool
    let isDirty: Bool
    var errorMessage: String? = nil
    let onSave: () -> Void
    let onRevert: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDiscard = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .frame(minHeight: 220)
                            .font(SportiliTypography.body)
                            .disabled(!canManage || isSaving)
                            .accessibilityLabel("Nota personale")

                        if text.isEmpty {
                            Text("Aggiungi una nota per questo esercizio…")
                                .foregroundStyle(.secondary)
                                .montserrat(size: 15)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                        }
                    }
                }

                if isSaving { Section { ProgressView("Salvataggio nota…") } }
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(SportiliTypography.bodySmall).foregroundStyle(SportiliPalette.onCriticalContainer) } }
                if !savedText.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Elimina nota", systemImage: "trash")
                                .montserrat(size: 17)
                        }
                        .disabled(!canManage || isSaving)
                    }
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        if isDirty { confirmsDiscard = true }
                        else { dismiss() }
                    }
                    .montserrat(size: 17)
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Salva") {
                            onSave()
                        }
                        .montserrat(size: 17)
                        .disabled(!isDirty || !canManage)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSaving || isDirty)
        .alert("Scartare le modifiche alla nota?", isPresented: $confirmsDiscard) {
            Button("Scarta modifiche", role: .destructive) { onRevert(); dismiss() }
            Button("Continua a modificare", role: .cancel) {}
        }
    }
}

// MARK: - Weight Entry Sheet

struct WeightEntrySheet: View {
    let mode: WeightDialogMode
    @Binding var weightInput: String
    let isSaving: Bool
    var errorMessage: String? = nil
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @FocusState private var isWeightFieldFocused: Bool

    private var record: WeightLog? {
        if case let .edit(log) = mode { return log }
        return nil
    }

    private var title: String {
        switch mode {
        case .create: return "Registra peso"
        case .edit: return "Modifica peso"
        case .hidden: return "Peso"
        }
    }

    private var hasValidWeight: Bool {
        parsedWeightInput(weightInput) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Peso (kg)").font(SportiliTypography.label), footer: Text("Usa la virgola o il punto, ad esempio 47,5.").font(SportiliTypography.bodySmall)) {
                    TextField("Peso (kg)", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .font(SportiliTypography.body)
                        .focused($isWeightFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { if !isSaving { onConfirm() } }
                        .disabled(isSaving)
                        .accessibilityHint("Inserisci il peso in chilogrammi")
                }

                if isSaving { Section { ProgressView("Salvataggio peso…") } }
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(SportiliTypography.bodySmall).foregroundStyle(SportiliPalette.onCriticalContainer) } }
                else if !weightInput.isEmpty && !hasValidWeight {
                    Text("Inserisci un peso maggiore di zero, con virgola o punto.")
                        .font(SportiliTypography.bodySmall).foregroundStyle(SportiliPalette.onCriticalContainer)
                }
                Section(header: Text("Dettagli").font(SportiliTypography.label)) {
                    VStack(alignment: .leading, spacing: SportiliSpacing.compact) {
                        Text(record == nil ? "Data" : "Data della registrazione")
                            .font(SportiliTypography.label)
                        Text(EsercizioView.sheetDateFormatter.string(from: record?.date ?? Date()))
                            .font(SportiliTypography.body)
                            .foregroundStyle(SportiliPalette.onSurfaceMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                        .montserrat(size: 17)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .accessibilityLabel("Salvataggio peso")
                    } else {
                        Button("Salva", action: onConfirm)
                            .montserrat(size: 17)
                            .disabled(weightInput.isEmpty)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") {
                        isWeightFieldFocused = false
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear {
            isWeightFieldFocused = true
        }
    }
}

// MARK: - Chart

struct WeightChartView: View {
    let data: [UniformLog]
    let dateFormatter: DateFormatter

    private var xAxisIndices: [Int] {
        guard !data.isEmpty else { return [] }
        if data.count <= 4 {
            return data.map(\.index)
        }

        let step = max(1, data.count / 3)
        var selected = stride(from: 0, to: data.count, by: step).map { data[$0].index }
        if let last = data.last?.index, selected.last != last {
            selected.append(last)
        }
        return selected
    }

    var body: some View {
        Chart {
            ForEach(data) { item in
                LineMark(
                    x: .value("Campione", item.index),
                    y: .value("Peso", item.weight)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(SportiliPalette.primary)
            }

            ForEach(data) { item in
                PointMark(
                    x: .value("Campione", item.index),
                    y: .value("Peso", item.weight)
                )
                .symbolSize(55)
                .foregroundStyle(.tint)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: xAxisIndices) { value in
                if let idx = value.as(Int.self),
                   let item = data.first(where: { $0.index == idx }) {
                    AxisValueLabel {
                        Text("\(item.index)")
                            .font(SportiliTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(dateFormatter.string(from: item.date))
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
}

// MARK: - Full Screen Image

struct FullScreenImageView: View {
    var image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .accessibilityLabel("Chiudi immagine")
                }
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.bottom, 24)
                    .accessibilityLabel("Immagine dell’esercizio")
            }
        }
    }
}



// MARK: - Timer Sheet

struct TimerSheet: View {
    private static let fallbackDuration = 60

    private struct ParseResult {
        let seconds: Int
        let usedFallback: Bool
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var preferredGaugeSize: CGFloat = 220
    @State private var timeRemaining: Int
    @State private var totalTime: Int
    @State private var showsFallbackWarning: Bool
    @State private var timerIsActive = false
    @State private var timerPaused = false
    @State private var timer: Timer?

    @State private var audioPlayer: AVAudioPlayer?

    init(riposo: String) {
        let parsed = TimerSheet.parseRiposoResult(riposo)
        _timeRemaining = State(initialValue: parsed.seconds)
        _totalTime = State(initialValue: parsed.seconds)
        _showsFallbackWarning = State(initialValue: parsed.usedFallback)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: SportiliSpacing.section) {
                        Text("Tempo di recupero")
                            .font(SportiliTypography.headline)
                            .multilineTextAlignment(.center)

                        if showsFallbackWarning {
                            Label("Formato non riconosciuto: timer impostato a 1 minuto.", systemImage: "info.circle")
                                .font(SportiliTypography.bodySmall)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        ZStack {
                            Circle().stroke(SportiliPalette.surfaceMuted, lineWidth: 12)
                            Circle()
                                .trim(from: 0, to: CGFloat(timeRemaining) / CGFloat(max(totalTime, 1)))
                                .stroke(SportiliPalette.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .accessibilityHidden(true)

                            Text(formatTime(timeRemaining))
                                .font(SportiliTypography.headline)
                                .monospacedDigit()
                                .minimumScaleFactor(0.65)
                        }
                        .frame(
                            width: min(preferredGaugeSize, geometry.size.width - 64),
                            height: min(preferredGaugeSize, geometry.size.width - 64)
                        )
                        .accessibilityLabel("Tempo di recupero rimanente")
                        .accessibilityValue(formatTime(timeRemaining))
                        .padding(.vertical, SportiliSpacing.standard)

                        Text(timerStatus)
                            .font(SportiliTypography.body)
                            .foregroundStyle(.secondary)

                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: SportiliSpacing.small) { timerButtons }
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: SportiliSpacing.standard) { timerButtons }
                                VStack(spacing: SportiliSpacing.small) { timerButtons }
                            }
                        }
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
                    .padding(SportiliSpacing.section)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi", action: dismiss.callAsFunction)
                        .font(SportiliTypography.body)
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }

    @ViewBuilder
    private var timerButtons: some View {
        if timerIsActive {
            timerButton(title: "Pausa", systemImage: "pause.circle.fill", prominent: true, action: pauseTimer)
            timerButton(title: "Azzera", systemImage: "gobackward", prominent: false, action: resetTimer)
        } else {
            timerButton(
                title: timerPaused ? "Riprendi" : "Inizia",
                systemImage: "play.circle.fill",
                prominent: true,
                action: startTimer
            )
            timerButton(title: "Azzera", systemImage: "gobackward", prominent: false, action: resetTimer)
                .disabled(timeRemaining == totalTime)
        }
    }

    private var timerStatus: String {
        if timerIsActive { return "Timer in corso" }
        if timerPaused { return "Timer in pausa" }
        if timeRemaining == totalTime { return "Pronto per iniziare" }
        return "Timer completato"
    }

    @ViewBuilder
    private func timerButton(
        title: String,
        systemImage: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let button = Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(SportiliTypography.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 112, minHeight: 44)
        }
        if prominent {
            button.buttonStyle(.borderedProminent).tint(SportiliPalette.primary)
        } else {
            button.buttonStyle(.bordered).tint(SportiliPalette.primary)
        }
    }

    func startTimer() {
        guard !timerIsActive else { return }

        if timeRemaining == 0 { timeRemaining = totalTime }

        timerIsActive = true
        timerPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
                announceTimeIfNeeded()
            } else {
                timer?.invalidate()
                timer = nil
                timerIsActive = false
                timerPaused = false
                timeRemaining = 0
                UIAccessibility.post(notification: .announcement, argument: "Recupero terminato")
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

    private func announceTimeIfNeeded() {
        guard timeRemaining == 10 || timeRemaining == 5 else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(timeRemaining) secondi rimanenti"
        )
    }

    func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func parseRiposo(_ riposo: String) -> Int {
        parseRiposoResult(riposo).seconds
    }

    private static func parseRiposoResult(_ riposo: String) -> ParseResult {
        let cleaned = riposo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if cleaned.isEmpty {
            return ParseResult(seconds: fallbackDuration, usedFallback: true)
        }

        if let quoteSeconds = parseQuoteFormat(cleaned) {
            return ParseResult(seconds: quoteSeconds, usedFallback: false)
        }

        if let colonSeconds = parseColonFormat(cleaned) {
            return ParseResult(seconds: colonSeconds, usedFallback: false)
        }

        if let letterSeconds = parseLetterFormat(cleaned) {
            return ParseResult(seconds: letterSeconds, usedFallback: false)
        }

        if let pureSeconds = Int(cleaned), pureSeconds > 0 {
            return ParseResult(seconds: pureSeconds, usedFallback: false)
        }

        return ParseResult(seconds: fallbackDuration, usedFallback: true)
    }

    private static func parseQuoteFormat(_ value: String) -> Int? {
        let splitByQuote = value.split(separator: "'")
        guard splitByQuote.count == 2 else { return nil }

        let minutes = Int(splitByQuote[0].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let secondsString = splitByQuote[1]
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let seconds = Int(secondsString) ?? 0
        let total = minutes * 60 + seconds
        return total > 0 ? total : nil
    }

    private static func parseColonFormat(_ value: String) -> Int? {
        let components = value.split(separator: ":")
        guard components.count == 2 else { return nil }
        guard let minutes = Int(components[0]),
              let seconds = Int(components[1]) else { return nil }
        let total = minutes * 60 + seconds
        return total > 0 ? total : nil
    }

    private static func parseLetterFormat(_ value: String) -> Int? {
        // Supporta "2m 30s", "2m", "30s"
        let minutePattern = #"(\d+)\s*m"#
        let secondPattern = #"(\d+)\s*s"#

        let minutes = firstMatchInt(value: value, pattern: minutePattern) ?? 0
        let seconds = firstMatchInt(value: value, pattern: secondPattern) ?? 0
        let total = minutes * 60 + seconds
        return total > 0 ? total : nil
    }

    private static func firstMatchInt(value: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: value.utf16.count)
        guard let match = regex.firstMatch(in: value, range: range),
              let matchRange = Range(match.range(at: 1), in: value) else {
            return nil
        }
        return Int(value[matchRange])
    }

    func playSound() {
        AudioServicesPlaySystemSound(SystemSoundID(1022))
    }

    func triggerVibration() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview("Esercizio View") {
    NavigationStack {
        let exercise = PreviewData.singleExercise
        let previewModel = ExerciseDetailViewModel(
            userCode: "preview",
            autoObserve: false,
            initialData: PreviewData.exerciseData(for: exercise)
        )
        EsercizioView(
            giornoId: PreviewData.giorno.id,
            gruppoId: PreviewData.gruppo.id,
            esercizioId: exercise.id,
            esercizio: exercise,
            userCode: "preview",
            viewModel: previewModel,
            autoLoadImage: false
        )
    }
}

#Preview("Weight Chart") {
    let chartData = PreviewData.weightLogs.enumerated().map { index, log in
        UniformLog(id: index, index: index, date: log.date, weight: log.weight)
    }
    return WeightChartView(data: chartData, dateFormatter: EsercizioView.summaryDateFormatter)
        .frame(height: 240)
        .padding()
}

#Preview("Full Screen Image") {
    let image = UIImage(systemName: "figure.strengthtraining.traditional") ?? UIImage()
    return FullScreenImageView(image: image)
}
