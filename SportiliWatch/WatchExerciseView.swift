import SwiftUI

struct WatchExerciseView: View {
    let exercise: WatchExercise
    @EnvironmentObject private var store: WatchWorkoutStore
    @State private var editor: NumericEditor?
    @State private var restSeconds = 90.0
    @State private var saved = false
    @State private var savedRecordingID: String?
    private var savedItem: WatchQueueItem? {
        store.state.sync.queue.first { $0.id == savedRecordingID }
    }
    private var draft: WatchDraft { store.draft(for: exercise) }
    private func change(_ edit: (inout WatchDraft) -> Void) {
        var value = draft; edit(&value); store.edit(exercise, value); saved = false; savedRecordingID = nil
    }
    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.prescription)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(WatchStyle.accent)
                        if !exercise.rest.isEmpty {
                            Label(exercise.rest, systemImage: "timer").font(.caption2).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4).watchCard(accented: true)
                }
                Section {
                    Toggle("Pesi per serie", isOn: Binding(get: { !draft.singleMode }, set: { flag in
                        change { value in
                            value.singleMode = !flag
                            if flag && value.sets.isEmpty { value.sets = [WatchSet(reps: 10, weight: 20)] }
                        }
                    })).font(.caption).watchCard()
                    if draft.singleMode {
                        Button { editor = .single } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(draft.single, format: .number.precision(.fractionLength(0...2)))
                                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                Text("kg").font(.caption).foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                Image(systemName: "pencil").font(.caption).foregroundStyle(WatchStyle.accent)
                            }.padding(.vertical, 4)
                        }.accessibilityLabel("Modifica peso singolo").watchCard(accented: true)
                        if let weight = exercise.lastSingle {
                            Button { change { $0.single = weight } } label: {
                                Label("Usa ultimo peso", systemImage: "arrow.uturn.backward").font(.caption)
                            }.watchCard()
                        }
                        ForEach(exercise.repetitions.indices, id: \.self) { index in
                            Button { store.toggleCompleted(exercise, index: index) } label: {
                                Label("Serie \(index + 1) · \(exercise.repetitions[index]) rip.",
                                    systemImage: store.state.sync.completed[exercise.id]?.contains(index) == true ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline)
                            }.tint(store.state.sync.completed[exercise.id]?.contains(index) == true ? .green : WatchStyle.accent).watchCard()
                        }
                    } else {
                        if !exercise.reusableSets.isEmpty && exercise.reusableSets.map(\.reps) == draft.sets.map(\.reps) {
                            Button { change { $0.sets = exercise.reusableSets } } label: {
                                Label("Usa ultimi pesi", systemImage: "arrow.uturn.backward").font(.caption)
                            }.watchCard()
                        }
                        ForEach(draft.sets.indices, id: \.self) { index in
                            WatchSetRow(index: index, set: draft.sets[index],
                                completed: store.state.sync.completed[exercise.id]?.contains(index) == true,
                                toggle: { store.toggleCompleted(exercise, index: index) },
                                editReps: { editor = .reps(index) }, editWeight: { editor = .weight(index) })
                                .watchCard().id("watch-set-\(index)")
                        }
                        if draft.sets.count < 20 {
                            Button { change { $0.sets.append($0.sets.last ?? WatchSet(reps: 10, weight: 20)) } } label: {
                                Label("Aggiungi serie", systemImage: "plus.circle").font(.caption)
                            }.watchCard()
                        }
                        if draft.sets.count > 1 {
                            Button { change { $0.sets.removeLast() } } label: {
                                Label("Rimuovi ultima serie", systemImage: "minus.circle").font(.caption)
                            }.watchCard()
                        }
                    }
                    Button {
                        saved = store.save(exercise)
                        if saved { savedRecordingID = store.state.sync.queue.last?.id }
                    } label: {
                        Label(saved ? WatchRecordingText.title(for: savedItem?.receipt?.status) : "Salva pesi",
                              systemImage: saved ? (savedItem?.receipt?.status == .saved ? "checkmark" : "clock") : "tray.and.arrow.down")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
                    }.disabled(saved).tint(savedItem?.receipt?.status == .saved ? .green : WatchStyle.accent).watchCard(accented: true)
                    if saved, let item = savedItem, item.receipt?.status != .saved {
                        Text(WatchRecordingText.message(for: item, activeBinding: store.state.sync.snapshot?.binding))
                            .font(.caption2).foregroundStyle(.secondary).watchCard()
                        NavigationLink("Vedi stato invio") { WatchQueueView() }
                            .font(.caption).watchCard()
                    }
                } header: { WatchSectionTitle(text: "Pesi") }
                Section {
                    Button { editor = .rest } label: {
                        HStack {
                            Label("Recupero", systemImage: "timer").font(.caption)
                            Spacer(minLength: 0)
                            Text("\(Int(restSeconds)) s").font(.system(.body, design: .rounded, weight: .semibold)).monospacedDigit()
                        }
                    }.watchCard()
                    Button { store.startRest(seconds: restSeconds) } label: {
                        Label("Avvia recupero", systemImage: "play.fill").font(.headline)
                    }.watchCard(accented: true)
                    RestStatusView().watchCard(accented: true)
                } header: { WatchSectionTitle(text: "Recupero") }
                if exercise.lastSingle != nil || !exercise.lastSets.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            if let single = exercise.lastSingle {
                                Text("Ultimo peso singolo: \(single, specifier: "%g") kg").font(.caption)
                            }
                            if !exercise.lastSets.isEmpty {
                                Text(exercise.lastSets.map { "\($0.reps)×\($0.weight.formatted()) kg" }.joined(separator: " · "))
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4).watchCard()
                    } header: { WatchSectionTitle(text: "Ultimi carichi") }
                }
            }
            .navigationTitle(exercise.name)
            .onAppear {
                restSeconds = watchRestSeconds(from: exercise.rest) ?? 90
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--watch-screen=sets") {
                    DispatchQueue.main.async { proxy.scrollTo("watch-set-0", anchor: .top) }
                }
#endif
            }
            .sheet(item: $editor) { selection in
                CrownNumberEditor(title: selection.title, value: value(for: selection),
                    range: selection.range, step: selection.step) { number in
                        switch selection {
                        case .single: change { $0.single = number }
                        case .weight(let index): change { if $0.sets.indices.contains(index) { $0.sets[index].weight = number } }
                        case .reps(let index): change { if $0.sets.indices.contains(index) { $0.sets[index].reps = Int(number) } }
                        case .rest: restSeconds = number
                        }
                    }
            }
        }
    }
    private func value(for editor: NumericEditor) -> Double {
        switch editor {
        case .single: return draft.single
        case .weight(let i): return draft.sets.indices.contains(i) ? draft.sets[i].weight : 20
        case .reps(let i): return draft.sets.indices.contains(i) ? Double(draft.sets[i].reps) : 10
        case .rest: return restSeconds
        }
    }

}
private struct WatchSetRow: View {
    let index: Int
    let set: WatchSet
    let completed: Bool
    let toggle: () -> Void
    let editReps: () -> Void
    let editWeight: () -> Void
    var body: some View {
        VStack(spacing: 7) {
            Button(action: toggle) {
                HStack {
                    Text("Serie \(index + 1)").font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3).foregroundStyle(completed ? .green : .secondary)
                }.contentShape(Rectangle()).frame(minHeight: 44)
            }.buttonStyle(.plain)
                .accessibilityLabel("Serie \(index + 1), \(completed ? "completata" : "da completare")")
            HStack(spacing: 8) {
                numberButton(value: String(set.reps), unit: "rip.", action: editReps)
                    .accessibilityLabel("Ripetizioni serie \(index + 1): \(set.reps)")
                numberButton(value: set.weight.formatted(.number.precision(.fractionLength(0...2))), unit: "kg", action: editWeight)
                    .accessibilityLabel("Peso serie \(index + 1): \(set.weight.formatted()) kg")
            }
        }.padding(.vertical, 3)
    }
    private func numberButton(value: String, unit: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(value).font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(WatchStyle.accent)
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 46).padding(.vertical, 3)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }.buttonStyle(.plain)
    }
}

private enum NumericEditor: Identifiable {
    case single, weight(Int), reps(Int), rest
    var id: String { String(describing: self) }
    var title: String {
        switch self { case .single, .weight: return "Peso (kg)"; case .reps: return "Ripetizioni"; case .rest: return "Recupero (s)" }
    }
    var range: ClosedRange<Double> {
        switch self { case .single, .weight: return 0.25...2000; case .reps: return 1...1000; case .rest: return 5...3600 }
    }
    var step: Double {
        switch self { case .single, .weight: return 0.25; case .reps: return 1; case .rest: return 5 }
    }
}
private struct CrownNumberEditor: View {
    let title: String
    @State var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let save: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(WatchStyle.accent)
            Text(value, format: .number.precision(.fractionLength(0...2)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit().minimumScaleFactor(0.5)
                .focusable().focused($focused)
                .digitalCrownRotation($value, from: range.lowerBound, through: range.upperBound,
                    by: step, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                .accessibilityLabel(title)
                .accessibilityAdjustableAction { direction in
                    value = min(range.upperBound, max(range.lowerBound, value + (direction == .increment ? step : -step)))
                }
            HStack {
                Button { value = max(range.lowerBound, value - step) } label: {
                    Image(systemName: "minus").frame(maxWidth: .infinity, minHeight: 28)
                }.accessibilityLabel("Diminuisci")
                Button { value = min(range.upperBound, value + step) } label: {
                    Image(systemName: "plus").frame(maxWidth: .infinity, minHeight: 28)
                }.accessibilityLabel("Aumenta")
            }
            Button("Conferma") { save((value / step).rounded() * step); dismiss() }
                .buttonStyle(.borderedProminent).tint(WatchStyle.accent).foregroundStyle(.black)
        }.padding(.horizontal).onAppear { focused = true }
    }
}
#Preview("Allenamento offline") {
    WatchHomeView().environmentObject(WatchWorkoutStore(fixture: true))
}
#if DEBUG
struct WatchCrownFixture: View {
    var body: some View { CrownNumberEditor(title: "Peso (kg)", value: 35.5, range: 0.25...2000, step: 0.25) { _ in } }
}
#endif
