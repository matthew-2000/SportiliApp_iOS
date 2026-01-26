import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel

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
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    AlertsErrorState(error: error, onRetry: viewModel.retry)
                } else if viewModel.alerts.isEmpty {
                    AlertsEmptyState()
                } else {
                    List {
                        ForEach(viewModel.alerts) { alert in
                            AlertRow(alert: alert)
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(Text("Avvisi"))
        }
    }
}

private struct AlertsErrorState: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Impossibile caricare gli avvisi")
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .montserrat(size: 20)

            Text(error)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .montserrat(size: 16)

            Button(action: onRetry) {
                Text("Riprova")
                    .bold()
                    .montserrat(size: 18)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AlertsEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("Nessun avviso")
                .fontWeight(.semibold)
                .montserrat(size: 20)

            Text("Quando il tuo trainer pubblicherà un avviso lo troverai qui.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .montserrat(size: 16)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AlertRow: View {
    let alert: UserAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(alert.urgenza.displayName.uppercased(), systemImage: "exclamationmark.circle.fill")
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(backgroundColor.opacity(0.2))
                    .foregroundStyle(backgroundColor)
                    .clipShape(Capsule())
                    .montserrat(size: 13)

                Spacer()

                if let scadenza = alert.scadenza {
                    Text("Scade il \(AlertsView.dateFormatter.string(from: scadenza))")
                        .foregroundColor(.gray)
                        .montserrat(size: 13)
                }
            }

            Text(alert.titolo)
                .montserrat(size: 20)
                .bold()

            Text(alert.descrizione)
                .foregroundColor(.primary)
                .montserrat(size: 16)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }

    private var backgroundColor: Color {
        switch alert.urgenza {
        case .nessuna:
            return .gray
        case .bassa:
            return .blue
        case .media:
            return .primary
        case .alta:
            return .red
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
