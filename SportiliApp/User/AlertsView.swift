import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel

    private static let urgencyOrder: [UserAlert.Urgency] = [.alta, .media, .bassa, .nessuna]

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    init(viewModel: AlertsViewModel = AlertsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Caricamento avvisi")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                AlertsErrorState(error: error, onRetry: viewModel.retry)
            } else if viewModel.alerts.isEmpty {
                AlertsEmptyState()
            } else {
                List {
                    ForEach(Self.urgencyOrder, id: \.rawValue) { urgency in
                        let alerts = viewModel.alerts.filter { $0.urgenza == urgency }

                        if !alerts.isEmpty {
                            Section {
                                ForEach(alerts) { alert in
                                    AlertRow(alert: alert)
                                        .listRowInsets(
                                            EdgeInsets(
                                                top: SportiliSpacing.compact,
                                                leading: SportiliSpacing.standard,
                                                bottom: SportiliSpacing.compact,
                                                trailing: SportiliSpacing.standard
                                            )
                                        )
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                }
                            } header: {
                                Label(urgency.sectionTitle, systemImage: urgency.iconName)
                                    .font(SportiliTypography.label)
                                    .foregroundStyle(urgency.foregroundColor)
                                    .textCase(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(SportiliPalette.background)
            }
        }
        .background(SportiliPalette.background)
        .navigationTitle(Text("Avvisi"))
    }
}

private struct AlertsErrorState: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: SportiliSpacing.standard) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SportiliPalette.onWarningContainer)

            Text("Impossibile caricare gli avvisi")
                .multilineTextAlignment(.center)
                .font(SportiliTypography.titleLarge)
                .foregroundStyle(SportiliPalette.onSurface)

            Text(error)
                .foregroundStyle(SportiliPalette.onSurfaceMuted)
                .multilineTextAlignment(.center)
                .font(SportiliTypography.body)

            Button(action: onRetry) {
                Text("Riprova")
                    .font(SportiliTypography.title)
                    .frame(minHeight: 44)
                    .padding(.horizontal, SportiliSpacing.section)
            }
            .buttonStyle(.borderedProminent)
            .tint(SportiliPalette.primary)
            .foregroundStyle(SportiliPalette.onPrimary)
        }
        .padding(SportiliSpacing.standard)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AlertsEmptyState: View {
    var body: some View {
        VStack(spacing: SportiliSpacing.small) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 50))
                .foregroundStyle(SportiliPalette.onSurfaceMuted)

            Text("Nessun avviso")
                .font(SportiliTypography.titleLarge)
                .foregroundStyle(SportiliPalette.onSurface)

            Text("Quando il tuo trainer pubblicherà un avviso lo troverai qui.")
                .foregroundStyle(SportiliPalette.onSurfaceMuted)
                .multilineTextAlignment(.center)
                .font(SportiliTypography.body)
        }
        .padding(SportiliSpacing.standard)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AlertRow: View {
    let alert: UserAlert

    var body: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.small) {
            Text(alert.titolo)
                .font(SportiliTypography.titleLarge)
                .foregroundStyle(SportiliPalette.onSurface)
                .fixedSize(horizontal: false, vertical: true)

            Text(alert.descrizione)
                .foregroundStyle(SportiliPalette.onSurface)
                .font(SportiliTypography.body)
                .fixedSize(horizontal: false, vertical: true)

            if let scadenza = alert.scadenza {
                expiryLabel(for: scadenza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SportiliSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: SportiliShape.container)
                .fill(SportiliPalette.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(alert.urgenza.sectionTitle)
    }

    private func expiryLabel(for date: Date) -> some View {
        Label(
            "Scade il \(AlertsView.dateFormatter.string(from: date))",
            systemImage: "calendar"
        )
        .foregroundStyle(SportiliPalette.onSurfaceMuted)
        .font(SportiliTypography.metadata)
    }
}

private extension UserAlert.Urgency {
    var sectionTitle: String {
        switch self {
        case .alta: return "Priorità alta"
        case .media: return "Priorità media"
        case .bassa: return "Priorità bassa"
        case .nessuna: return "Senza priorità"
        }
    }

    var iconName: String {
        switch self {
        case .nessuna: return "bell"
        case .bassa: return "info.circle.fill"
        case .media: return "exclamationmark.circle.fill"
        case .alta: return "exclamationmark.triangle.fill"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .nessuna: return SportiliPalette.onSurfaceMuted
        case .bassa: return SportiliPalette.onInfoContainer
        case .media: return SportiliPalette.onWarningContainer
        case .alta: return SportiliPalette.onCriticalContainer
        }
    }
}

#Preview("Alerts - Loaded") {
    AlertsView(
        viewModel: AlertsViewModel(autoObserve: false, initialAlerts: PreviewData.alerts)
    )
}

#Preview("Alerts - Empty") {
    AlertsView(
        viewModel: AlertsViewModel(autoObserve: false, initialAlerts: [])
    )
}

#Preview("Alerts - Error") {
    AlertsView(
        viewModel: AlertsViewModel(autoObserve: false, initialErrorMessage: "Connessione non disponibile")
    )
}

#Preview("Alerts - Dark") {
    NavigationStack {
        AlertsView(
            viewModel: AlertsViewModel(autoObserve: false, initialAlerts: PreviewData.alerts)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Alerts - Accessibility text") {
    NavigationStack {
        AlertsView(
            viewModel: AlertsViewModel(autoObserve: false, initialAlerts: PreviewData.alerts)
        )
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}
