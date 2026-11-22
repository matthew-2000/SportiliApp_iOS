import SwiftUI

/// A single entry point shared by every tab and its navigation destinations.
struct RestTimerBar: View {
    @ObservedObject private var rest = PhoneRestTimer.shared
    let openTimer: () -> Void

    var body: some View {
        Group {
            if rest.deadline != nil || rest.completedAt != nil {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: openTimer) {
                            HStack(spacing: 10) {
                                Image(systemName: rest.completedAt == nil ? "timer" : "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(SportiliPalette.primary)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rest.completedAt == nil ? "Recupero" : "Recupero terminato")
                                        .font(SportiliTypography.label)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .foregroundStyle(SportiliPalette.onSurface)
                                    if let name = rest.exerciseName {
                                        Text(name)
                                            .font(SportiliTypography.metadata)
                                            .foregroundStyle(SportiliPalette.onSurfaceMuted)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if let deadline = rest.deadline {
                                    Text(timerInterval: Date.distantPast...deadline, countsDown: true)
                                        .font(SportiliTypography.titleLarge)
                                        .monospacedDigit()
                                        .foregroundStyle(SportiliPalette.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80, alignment: .trailing)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
                                    .accessibilityHidden(true)
                            }
                            .padding(.leading, 12)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Apre il timer di recupero")

                        Button {
                            if rest.deadline != nil { rest.stop() }
                            else { rest.dismissCompletion() }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SportiliPalette.onSurfaceMuted)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(rest.deadline != nil ? "Interrompi recupero" : "Chiudi avviso")
                    }

                    if let start = rest.startedAt, let end = rest.deadline {
                        ProgressView(timerInterval: start...end, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(SportiliPalette.primary)
                        .accessibilityHidden(true)
                    }
                }
                .background(SportiliPalette.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: SportiliShape.control, style: .continuous))
                .padding(.horizontal, SportiliSpacing.standard)
                .padding(.vertical, 6)
                .background(SportiliPalette.background)
            }
        }
        .task(id: rest.deadline) {
            guard let end = rest.deadline else { return }
            do { try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow))) }
            catch { return }
            guard rest.deadline == end else { return }
            rest.reconcile()
        }
        .task(id: rest.completedAt) {
            guard let completed = rest.completedAt else { return }
            do { try await Task.sleep(for: .seconds(8)) }
            catch { return }
            guard rest.completedAt == completed, rest.deadline == nil else { return }
            rest.dismissCompletion()
        }
    }
}
