import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel = AlertsViewModel()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("Impossibile caricare gli avvisi")
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .montserrat(size: 20)

                        Text(error)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .montserrat(size: 16)

                        Button(action: {
                            viewModel.retry()
                        }) {
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
                } else if viewModel.alerts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("Nessun avviso")
                            .font(.title3.weight(.semibold))
                            .montserrat(size: 20)

                        Text("Quando il tuo trainer pubblicherà un avviso lo troverai qui.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .montserrat(size: 16)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .navigationTitle("Avvisi")
        }
    }
}

private struct AlertRow: View {
    let alert: UserAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(alert.urgenza.displayName.uppercased(), systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(backgroundColor.opacity(0.2))
                    .foregroundStyle(backgroundColor)
                    .clipShape(Capsule())
                    .montserrat(size: 13)

                Spacer()

                if let scadenza = alert.scadenza {
                    Text("Scade il \(AlertsView.dateFormatter.string(from: scadenza))")
                        .font(.caption)
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

#Preview {
    AlertsView()
}
