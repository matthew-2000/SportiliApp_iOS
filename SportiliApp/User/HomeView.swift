//
//  HomeView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var nomeUtente: String?
    @StateObject private var schedaViewModel: SchedaViewModel
    @State private var isRequesting = false
    @State private var requestWasSent = false
    @State private var requestErrorMessage: String?

    private let previewUserName: String?

    init(
        schedaViewModel: SchedaViewModel = SchedaViewModel(),
        previewUserName: String? = nil
    ) {
        _schedaViewModel = StateObject(wrappedValue: schedaViewModel)
        self.previewUserName = previewUserName
    }

    var body: some View {
        Group {
            if schedaViewModel.isLoading || !schedaViewModel.hasLoadedOnce {
                HomeLoadingState()
            } else if schedaViewModel.errorMessage != nil {
                HomeErrorState(onRetry: schedaViewModel.fetchScheda)
            } else if let scheda = schedaViewModel.scheda {
                homeList(for: scheda)
            } else {
                HomeEmptyState(onRetry: schedaViewModel.fetchScheda)
            }
        }
        .background(SportiliPalette.background)
        .navigationTitle("Scheda")
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: updateUserName)
    }

    private func homeList(for scheda: Scheda) -> some View {
        List {
            if let nomeUtente {
                Text("Ciao, \(nomeUtente)")
                    .font(SportiliTypography.body)
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityAddTraits(.isHeader)
            }

            SchedaSummary(scheda: scheda)
                .listRowInsets(EdgeInsets(
                    top: SportiliSpacing.compact,
                    leading: SportiliSpacing.standard,
                    bottom: SportiliSpacing.compact,
                    trailing: SportiliSpacing.standard
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            SchedaStatusCard(
                status: status(for: scheda),
                scheda: scheda,
                isRequesting: isRequesting,
                requestErrorMessage: requestErrorMessage,
                onRequest: requestSchedaUpdate
            )
            .listRowInsets(EdgeInsets(
                top: SportiliSpacing.compact,
                leading: SportiliSpacing.standard,
                bottom: SportiliSpacing.section,
                trailing: SportiliSpacing.standard
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section {
                if scheda.giorni.isEmpty {
                    Label("Nessun allenamento inserito", systemImage: "figure.strengthtraining.traditional")
                        .font(SportiliTypography.body)
                        .foregroundStyle(SportiliPalette.onSurfaceMuted)
                        .padding(.vertical, SportiliSpacing.standard)
                } else {
                    ForEach(scheda.giorni, id: \.id) { giorno in
                        NavigationLink(destination: DayView(day: giorno)) {
                            DayRow(day: giorno)
                        }
                        .accessibilityHint("Apre l'allenamento \(giorno.name)")
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                Text("Allenamenti")
                    .font(SportiliTypography.label)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SportiliPalette.background)
        .refreshable {
            schedaViewModel.fetchScheda()
        }
    }

    private func status(for scheda: Scheda) -> SchedaDisplayStatus {
        if scheda.cambioRichiesto || requestWasSent {
            return .requested
        }
        if scheda.isScaduta {
            return .expired
        }
        return scheda.isInScadenza ? .expiring : .active
    }

    private func updateUserName() {
        if let previewUserName {
            nomeUtente = previewUserName
        } else {
            nomeUtente = Auth.auth().currentUser?.displayName
        }
    }

    private func requestSchedaUpdate() {
        guard !isRequesting else { return }
        guard let scheda = schedaViewModel.scheda, scheda.isScaduta else { return }
        guard let code = UserDefaults.standard.string(forKey: "code") else {
            requestErrorMessage = "Non riusciamo a inviare la richiesta. Effettua di nuovo l'accesso."
            return
        }

        isRequesting = true
        requestErrorMessage = nil
        SchedaManager().richiediCambioScheda(code: code) { success in
            DispatchQueue.main.async {
                isRequesting = false
                if success {
                    requestWasSent = true
                    schedaViewModel.fetchScheda()
                } else {
                    requestErrorMessage = "Non riusciamo a inviare la richiesta. Controlla la connessione e riprova."
                }
            }
        }
    }
}

private enum SchedaDisplayStatus: Equatable {
    case active
    case expiring
    case expired
    case requested

    var title: String {
        switch self {
        case .active: "Scheda attiva"
        case .expiring: "Scheda in scadenza"
        case .expired: "Scheda terminata"
        case .requested: "Richiesta inviata"
        }
    }

    var message: String {
        switch self {
        case .active: "Continua dal prossimo allenamento."
        case .expiring: "La scheda terminerà a breve."
        case .expired: "Chiedi al trainer una nuova scheda."
        case .requested: "Il trainer ha ricevuto la richiesta."
        }
    }

    var icon: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .expiring: "clock.badge.exclamationmark.fill"
        case .expired: "calendar.badge.exclamationmark"
        case .requested: "paperplane.circle.fill"
        }
    }

    var container: Color {
        switch self {
        case .active: SportiliPalette.successContainer
        case .expiring: SportiliPalette.warningContainer
        case .expired: SportiliPalette.criticalContainer
        case .requested: SportiliPalette.infoContainer
        }
    }

    var foreground: Color {
        switch self {
        case .active: SportiliPalette.onSuccessContainer
        case .expiring: SportiliPalette.onWarningContainer
        case .expired: SportiliPalette.onCriticalContainer
        case .requested: SportiliPalette.onInfoContainer
        }
    }
}

private struct SchedaSummary: View {
    let scheda: Scheda

    var body: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.standard) {
            Text("Riepilogo")
                .font(SportiliTypography.label)
                .foregroundStyle(SportiliPalette.onSurfaceMuted)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: SportiliSpacing.section) {
                    summaryItems
                }
                VStack(alignment: .leading, spacing: SportiliSpacing.standard) {
                    summaryItems
                }
            }
        }
        .padding(SportiliSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SportiliPalette.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var summaryItems: some View {
        SummaryItem(label: "Data di inizio", value: scheda.dataInizio.formatted(date: .abbreviated, time: .omitted))
            .frame(maxWidth: .infinity, alignment: .leading)
        SummaryItem(label: "Durata", value: "\(scheda.durata) \(scheda.durata == 1 ? "settimana" : "settimane")")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SummaryItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(SportiliTypography.bodySmall)
                .foregroundStyle(SportiliPalette.onSurfaceMuted)
            Text(value)
                .font(SportiliTypography.title)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SchedaStatusCard: View {
    let status: SchedaDisplayStatus
    let scheda: Scheda
    let isRequesting: Bool
    let requestErrorMessage: String?
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.small) {
            Label(status.title, systemImage: status.icon)
                .font(SportiliTypography.title)
                .foregroundStyle(status.foreground)
                .fixedSize(horizontal: false, vertical: true)

            Text(status.message)
                .font(SportiliTypography.body)
                .foregroundStyle(status.foreground)
                .fixedSize(horizontal: false, vertical: true)

            if status == .active || status == .expiring {
                Text(scheda.tempoRimanente())
                    .font(SportiliTypography.bodySmall)
                    .foregroundStyle(status.foreground)
            }

            if status == .expired {
                Button(action: onRequest) {
                    HStack(spacing: SportiliSpacing.compact) {
                        if isRequesting {
                            ProgressView()
                                .tint(SportiliPalette.onPrimary)
                        }
                        Text(isRequesting ? "Invio in corso…" : "Richiedi nuova scheda")
                    }
                }
                .buttonStyle(SportiliPrimaryButtonStyle())
                .disabled(isRequesting)
                .padding(.top, 4)
            }

            if let requestErrorMessage {
                Label(requestErrorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(SportiliTypography.bodySmall)
                    .foregroundStyle(status.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Errore. \(requestErrorMessage)")
            }
        }
        .padding(SportiliSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.container)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isRequesting)
    }
}

private struct HomeLoadingState: View {
    var body: some View {
        List {
            SchedaSummary(scheda: PreviewData.scheda)
            SchedaStatusCard(
                status: .active,
                scheda: PreviewData.scheda,
                isRequesting: false,
                requestErrorMessage: nil,
                onRequest: {}
            )
            ForEach(0..<3, id: \.self) { _ in
                DayRow(day: PreviewData.giorno)
            }
        }
        .redacted(reason: .placeholder)
        .disabled(true)
        .overlay {
            ProgressView("Caricamento scheda…")
                .font(SportiliTypography.bodySmall)
                .padding(SportiliSpacing.standard)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Caricamento scheda")
    }
}

private struct HomeErrorState: View {
    let onRetry: () -> Void

    var body: some View {
        HomeUnavailableState(
            icon: "wifi.exclamationmark",
            title: "Scheda non disponibile",
            message: "Controlla la connessione e riprova.",
            actionTitle: "Riprova",
            action: onRetry
        )
    }
}

private struct HomeEmptyState: View {
    let onRetry: () -> Void

    var body: some View {
        HomeUnavailableState(
            icon: "list.bullet.clipboard",
            title: "Nessuna scheda disponibile",
            message: "Quando il trainer ne assegnerà una, la troverai qui.",
            actionTitle: "Riprova",
            action: onRetry
        )
    }
}

private struct HomeUnavailableState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: SportiliSpacing.standard) {
                Image(systemName: icon)
                    .font(.system(size: 42))
                    .foregroundStyle(SportiliPalette.primary)
                    .accessibilityHidden(true)

                Text(title)
                    .font(SportiliTypography.headline)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(SportiliTypography.body)
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    .multilineTextAlignment(.center)

                Button(actionTitle, action: action)
                    .font(SportiliTypography.label)
                    .buttonStyle(.borderedProminent)
                    .tint(SportiliPalette.primary)
                    .foregroundStyle(SportiliPalette.onPrimary)
                    .controlSize(.large)
            }
            .padding(SportiliSpacing.section)
            .frame(maxWidth: .infinity)
        }
    }
}

private extension Scheda {
    var isInScadenza: Bool {
        guard !isScaduta,
              let endDate = Calendar.current.date(byAdding: .weekOfYear, value: durata, to: dataInizio) else {
            return false
        }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return days < 7
    }
}

#Preview("Scheda attiva") {
    NavigationStack {
        HomeView(
            schedaViewModel: SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.activeScheda),
            previewUserName: "Matteo"
        )
    }
}

#Preview("Scheda terminata") {
    NavigationStack {
        HomeView(
            schedaViewModel: SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.expiredScheda),
            previewUserName: "Matteo"
        )
    }
}

#Preview("Richiesta inviata - dark") {
    NavigationStack {
        HomeView(
            schedaViewModel: SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.requestedScheda),
            previewUserName: "Matteo"
        )
    }
    .preferredColorScheme(.dark)
}
