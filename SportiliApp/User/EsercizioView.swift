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
import FirebaseDatabase

// MARK: - Models (UI)

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

    // Note
    @State private var noteInput: String
    @State private var lastSyncedNote: String
    @State private var lastSyncedNoteKey: String
    @State private var showNotesSheet = false

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

    init(
        giornoId: String,
        gruppoId: String,
        esercizioId: String,
        esercizio: Esercizio,
        userCode: String? = nil,
        viewModel: ExerciseDetailViewModel? = nil,
        imageLoader: ImageLoader = ImageLoader(),
        autoLoadImage: Bool = true
    ) {
        self.giornoId = giornoId
        self.gruppoId = gruppoId
        self.esercizioId = esercizioId
        self.esercizio = esercizio
        self.autoLoadImage = autoLoadImage

        let resolvedCode = userCode ?? UserDefaults.standard.string(forKey: "code") ?? ""
        let resolvedViewModel = viewModel ?? ExerciseDetailViewModel(userCode: resolvedCode)
        _viewModel = StateObject(wrappedValue: resolvedViewModel)
        _imageLoader = StateObject(wrappedValue: imageLoader)

        let initialPartName = EsercizioView.primaryExerciseName(from: esercizio.name)
        let initialKey = ExerciseDetailViewModel.makeExerciseKey(from: initialPartName)
        _dialogExerciseKey = State(initialValue: initialKey)

        let initialNote = esercizio.noteUtente ?? ""
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

    // MARK: - Body

    var body: some View {
        let parts = Self.exerciseParts(from: esercizio.name)
        let currentIndex = min(selectedPartIndex, max(parts.count - 1, 0))
        let currentPartName = Self.partName(at: currentIndex, from: parts, fallback: esercizio.name)
        let currentKey = ExerciseDetailViewModel.makeExerciseKey(from: currentPartName)

        let currentData = viewModel.data(for: currentKey)
        let sortedLogs = currentData?.sortedWeightLogs ?? []
        let recentLogs = Array(sortedLogs.suffix(10))
        let savedNote = currentData?.noteUtente ?? ""
        let isNoteDirty = noteInput != savedNote
        let latestRecord = sortedLogs.last

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

        return List {
            Section {
                ExerciseTitleBlock(
                    title: esercizio.name,
                    subtitle: heroSubtitle   // oppure nil se non la vuoi
                )
                ExerciseHeroHeader(
                    state: heroState,
                    title: esercizio.name,
                    subtitle: heroSubtitle,
                    onTap: { showFullScreenImage = true }
                )
            }

            if parts.count > 1 {
                Section(header: Text("Variazioni").montserrat(size: 17)) {
                    ExerciseVariationPicker(parts: parts, selectedIndex: $selectedPartIndex)
                }
            }

            Section(header: Text("Programma").montserrat(size: 17)) {
                ExerciseSerieRow(serie: esercizio.serie)

                if let riposo = esercizio.riposo, !riposo.isEmpty {
                    LabeledContent {
                        Text(riposo)
                            .montserrat(size: 17)
                            .fontWeight(.bold)
                    } label: {
                        Label("Recupero", systemImage: "timer")
                            .montserrat(size: 15)
                            .fontWeight(.semibold)
                    }
                }

                if let notePT = esercizio.notePT, !notePT.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CoachNotesRow(text: notePT)
                }
            }
            
            Section(header: Text("Note personali").montserrat(size: 17)) {
                if savedNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Nessuna nota salvata.")
                        .montserrat(size: 15)
                        .foregroundStyle(.secondary)
                } else {
                    Text(savedNote)
                        .lineLimit(10)
                        .montserrat(size: 17)
                }
                NotesPreviewRow(
                    text: savedNote,
                    isDirty: isNoteDirty,
                    onTap: { showNotesSheet = true }
                )
            }

            Section(header: Text("Progressi").montserrat(size: 17)) {
                if recentLogs.isEmpty {
                    EmptyStateRow(
                        title: "Nessun peso registrato",
                        message: "Registra il tuo primo peso cliccando sul + in alto per visualizzare i progressi.",
                        systemImage: "scalemass"
                    )
                    .padding(.vertical, 6)
                } else {
                    let chartData = recentLogs.enumerated().map { idx, log in
                        UniformLog(id: idx, index: idx, date: log.date, weight: log.weight)
                    }
                    WeightChartCard(data: chartData, dateFormatter: Self.logDateFormatter)
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
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Timer
                if let riposo = esercizio.riposo, !riposo.isEmpty {
                    Button {
                        showTimerSheet = true
                    } label: {
                        Image(systemName: "timer")
                    }
                    .accessibilityLabel("Avvia timer recupero")
                }

                // Add weight
                Button {
                    dialogExerciseKey = currentKey
                    weightDialogMode = .create
                    weightInput = ""
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Registra peso")
                .disabled(!canManageData)
            }
        }
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
        .sheet(isPresented: $showNotesSheet) {
            NotesEditorSheet(
                title: "Note personali",
                text: $noteInput,
                savedText: savedNote,
                canManage: canManageData,
                isDirty: isNoteDirty,
                onSave: { saveNote(for: currentKey) },
                onRevert: { noteInput = savedNote },
                onDelete: { removeNote(for: currentKey) }
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
            Text("Elimina peso").montserrat(size: 17),
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
                title: Text("Errore").montserrat(size: 17),
                message: Text(alert.message).montserrat(size: 15),
                dismissButton: .default(Text("OK").montserrat(size: 17))
            )
        }
        .onAppear {
            let initialPartName = Self.primaryExerciseName(from: esercizio.name)
            loadExerciseImage(for: initialPartName)
        }
        .onReceive(viewModel.$exerciseData) { _ in
            syncNote(for: currentKey, force: false)
        }
        .onChange(of: selectedPartIndex) { newIndex in
            let newPartName = Self.partName(at: newIndex, from: parts, fallback: esercizio.name)
            let newKey = ExerciseDetailViewModel.makeExerciseKey(from: newPartName)

            dialogExerciseKey = newKey
            syncNote(for: newKey, force: true)

            // reset transiente
            weightDialogMode = .hidden
            weightInput = ""
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
        weightDialogMode = .hidden
        weightInput = ""
    }

    // MARK: - Weight actions

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

    // MARK: - Notes actions (includes scheda sync)

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
                updateSchedaNote(sanitized) { schedaResult in
                    switch schedaResult {
                    case .success:
                        noteInput = sanitized
                        lastSyncedNote = sanitized
                        lastSyncedNoteKey = key
                        showToast(message: "Nota salvata")
                    case .failure(let message):
                        showError(message.errorDescription ?? "Errore sconosciuto")
                    }
                }
            case .failure(let message):
                showError(message.errorDescription ?? "Errore sconosciuto")
            }
        }
    }

    private func removeNote(for key: String) {
        viewModel.updateUserNote(for: key, note: nil) { result in
            switch result {
            case .success:
                updateSchedaNote(nil) { schedaResult in
                    switch schedaResult {
                    case .success:
                        noteInput = ""
                        lastSyncedNote = ""
                        lastSyncedNoteKey = key
                        showToast(message: "Nota rimossa", color: .orange)
                    case .failure(let message):
                        showError(message.errorDescription ?? "Errore sconosciuto")
                    }
                }
            case .failure(let message):
                showError(message.errorDescription ?? "Errore sconosciuto")
            }
        }
    }

    private func updateSchedaNote(_ note: String?, completion: @escaping (Result<Void, ExerciseDataError>) -> Void) {
        guard !viewModel.userCode.isEmpty else {
            completion(.failure(.message("Codice utente non valido")))
            return
        }

        let reference = Database.database().reference()
            .child("users")
            .child(viewModel.userCode)
            .child("scheda")
            .child("giorni")
            .child(giornoId)
            .child("gruppiMuscolari")
            .child(gruppoId)
            .child("esercizi")
            .child(esercizioId)
            .child("noteUtente")

        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reference.setValue(note) { error, _ in
                if let error {
                    completion(.failure(.message(error.localizedDescription)))
                } else {
                    completion(.success(()))
                }
            }
        } else {
            reference.removeValue { error, _ in
                if let error {
                    completion(.failure(.message(error.localizedDescription)))
                } else {
                    completion(.success(()))
                }
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

private struct ExerciseTitleBlock: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .montserrat(size: 28)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .montserrat(size: 15)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
    let title: String
    let subtitle: String?
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            overlay
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            if case .loaded = state { onTap() }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
    }

    @ViewBuilder
    private var background: some View {
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(ProgressView())
        case .failed:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Immagine non disponibile")
                            .montserrat(size: 13)
                            .foregroundStyle(.secondary)
                    }
                )
        }
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .montserrat(size: 20)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .montserrat(size: 15)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(16)
    }
}

// MARK: - Rows & Components (iOS 16 safe)

private struct ExerciseVariationPicker: View {
    let parts: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        Picker("Esercizio", selection: $selectedIndex) {
            ForEach(parts.indices, id: \.self) { idx in
                Text(parts[idx])
                    .montserrat(size: 17)
                    .tag(idx)
            }
        }
        .montserrat(size: 17)
        .pickerStyle(.segmented)
    }
}

private struct ExerciseSerieRow: View {
    let serie: String

    var body: some View {
        HStack(alignment: .center) {
            Label("Serie", systemImage: "figure.strengthtraining.functional")
                .montserrat(size: 15)
                .fontWeight(.semibold)
            Spacer()
            Text(serie)
                .montserrat(size: 20)
                .bold()
        }
        .padding(.vertical, 4)
    }
}

private struct CoachNotesRow: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Note del coach", systemImage: "person.text.rectangle")
                .montserrat(size: 15)
                .fontWeight(.semibold)
            Text(text)
                .montserrat(size: 15)
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyStateRow: View {
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

private struct WeightChartCard: View {
    let data: [UniformLog]
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Andamento (ultimi 10)", systemImage: "chart.line.uptrend.xyaxis")
                .montserrat(size: 15)
                .fontWeight(.semibold)

            WeightChartView(data: data, dateFormatter: dateFormatter)
                .frame(height: 220)
        }
        .padding(.vertical, 6)
    }
}

private struct WeightLogRow: View {
    let date: String
    let weight: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(weight)
                    .montserrat(size: 17)
                    .fontWeight(.semibold)
                Text(date)
                    .montserrat(size: 12)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.left.slash.chevron.right") // micro “tech” touch
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .opacity(0.0) // lascia spazio senza rumore visivo
        }
        .contentShape(Rectangle())
    }
}

private struct NotesPreviewRow: View {
    let text: String
    let isDirty: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Apri editor note")
                            .montserrat(size: 17)
                            .fontWeight(.semibold)
                        if isDirty {
                            Text("• modifiche")
                                .montserrat(size: 12)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Notes Sheet (Pro)

private struct NotesEditorSheet: View {
    let title: String
    @Binding var text: String
    let savedText: String
    let canManage: Bool
    let isDirty: Bool
    let onSave: () -> Void
    let onRevert: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .frame(minHeight: 220)
                            .montserrat(size: 17)

                        if text.isEmpty {
                            Text("Aggiungi una nota per questo esercizio…")
                                .foregroundStyle(.secondary)
                                .montserrat(size: 15)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                        }
                    }
                }

                if !savedText.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Elimina nota", systemImage: "trash")
                                .montserrat(size: 17)
                        }
                        .disabled(!canManage)
                    }
                }
            }
            .navigationTitle(Text(title).montserrat(size: 20))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        onRevert()
                        dismiss()
                    }
                    .montserrat(size: 17)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        onSave()
                        dismiss()
                    }
                    .montserrat(size: 17)
                    .disabled(!isDirty || !canManage)
                }
            }
        }
    }
}

// MARK: - Weight Entry Sheet

private struct WeightEntrySheet: View {
    let mode: WeightDialogMode
    @Binding var weightInput: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Peso").montserrat(size: 17)) {
                    TextField("Peso (kg)", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .montserrat(size: 17)
                }

                Section(header: Text("Dettagli").montserrat(size: 17)) {
                    if let record {
                        LabeledContent {
                            Text(EsercizioView.sheetDateFormatter.string(from: record.date))
                                .foregroundStyle(.secondary)
                                .montserrat(size: 15)
                        } label: {
                            Text("Ultimo aggiornamento")
                                .montserrat(size: 15)
                        }
                    } else {
                        LabeledContent {
                            Text(EsercizioView.sheetDateFormatter.string(from: Date()))
                                .foregroundStyle(.secondary)
                                .montserrat(size: 15)
                        } label: {
                            Text("Data")
                                .montserrat(size: 15)
                        }
                    }
                }
            }
            .navigationTitle(Text(title).montserrat(size: 20))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                        .montserrat(size: 17)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: onConfirm)
                        .montserrat(size: 17)
                }
            }
        }
    }
}

// MARK: - Chart

struct WeightChartView: View {
    let data: [UniformLog]
    let dateFormatter: DateFormatter

    private var lineGradient: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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
                .symbolSize(55)
                .foregroundStyle(.tint)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: data.map { $0.index }) { value in
                if let idx = value.as(Int.self),
                   let item = data.first(where: { $0.index == idx }) {
                    AxisValueLabel {
                        Text(dateFormatter.string(from: item.date))
                            .montserrat(size: 11)
                            .foregroundStyle(.secondary)
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
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.bottom, 24)
            }
        }
    }
}



// MARK: - Timer Sheet

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
                        .trim(from: 0, to: CGFloat(Double(timeRemaining) / Double(max(totalTime, 1))))
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
                                .montserrat(size: 17)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: resetTimer) {
                            Label("Reset", systemImage: "gobackward")
                                .montserrat(size: 17)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Button(action: startTimer) {
                            Label(timerPaused ? "Riprendi" : "Inizia", systemImage: "play.circle")
                                .montserrat(size: 17)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: resetTimer) {
                            Label("Reset", systemImage: "gobackward")
                                .montserrat(size: 17)
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
            }
            .montserrat(size: 17))
            .interactiveDismissDisabled(true)
        }
    }

    func startTimer() {
        guard !timerIsActive else { return }

        if timeRemaining == 0 { timeRemaining = totalTime }

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

#Preview("Esercizio View") {
    NavigationView {
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
