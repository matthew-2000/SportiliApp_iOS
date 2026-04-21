//
//  HomeView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI
import FirebaseAuth
import SwiftToast

struct HomeView: View {
    @State private var nomeUtente: String?
    @StateObject private var schedaViewModel: SchedaViewModel

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastColor: Color = .green
    @State private var isRequesting = false

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
            if schedaViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = schedaViewModel.errorMessage {
                HomeErrorState(errorMessage: errorMessage, onRetry: schedaViewModel.fetchScheda)
            } else if let scheda = schedaViewModel.scheda {
                homeList(for: scheda)
            } else if schedaViewModel.hasLoadedOnce {
                HomeEmptyState(onRetry: schedaViewModel.fetchScheda)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toast(
            isPresented: $showToast,
            message: toastMessage,
            duration: 2.5,
            backgroundColor: toastColor,
            textColor: .white,
            font: .callout,
            position: .bottom,
            animationStyle: .slide
        )
        .onAppear(perform: updateUserName)
        .navigationTitle(Text(getTitle()))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func homeList(for scheda: Scheda) -> some View {
        let settimaneRimanenti = scheda.getDurataScheda()

        List {
            header(for: scheda, settimaneRimanenti: settimaneRimanenti)

            if scheda.isScaduta {
                ExpiredSchedaBanner(
                    cambioRichiesto: scheda.cambioRichiesto,
                    isRequesting: isRequesting,
                    onRequest: requestSchedaUpdate
                )
            } else {
                ActiveSchedaBanner(settimaneRimanenti: settimaneRimanenti)
            }

            ForEach(scheda.giorni, id: \.id) { giorno in
                NavigationLink(destination: DayView(day: giorno)) {
                    DayRow(day: giorno)
                }
            }
        }
        .listStyle(.automatic)
        .refreshable {
            schedaViewModel.fetchScheda()
        }
    }

    private func header(for scheda: Scheda, settimaneRimanenti: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Inizio: \(getDateString(from: scheda))")
                    .montserrat(size: 20)
                    .fontWeight(.semibold)
                Text("x\(scheda.durata) sett.")
                    .montserrat(size: 25)
                    .foregroundColor(.accentColor)
                    .bold()
            }

            Label(
                settimaneRimanenti == 1 ? "1 settimana rimanente" : "\(settimaneRimanenti) settimane rimanenti",
                systemImage: "calendar.badge.clock"
            )
            .montserrat(size: 16)
            .foregroundStyle(settimaneRimanenti == 0 ? .red : .secondary)
        }
        .padding(.vertical, 20)
        .listRowSeparator(.hidden)
    }

    private func updateUserName() {
        if let previewUserName {
            nomeUtente = previewUserName
            return
        }

        if let currentUser = Auth.auth().currentUser {
            nomeUtente = currentUser.displayName
        }
    }

    private func requestSchedaUpdate() {
        guard !isRequesting else { return }
        guard let scheda = schedaViewModel.scheda, scheda.isScaduta else {
            showToast(
                message: "La nuova scheda può essere richiesta solo quando le settimane rimanenti sono 0.",
                color: .orange
            )
            return
        }
        guard let code = UserDefaults.standard.string(forKey: "code") else {
            showToast(message: "Codice utente mancante ❌", color: .red)
            return
        }

        isRequesting = true
        SchedaManager().richiediCambioScheda(code: code) { success in
            toastMessage = success ? "Richiesta inviata ✅" : "Errore durante la richiesta ❌"
            toastColor = success ? .green : .red
            showToast = true
            if success {
                schedaViewModel.fetchScheda()
            }
            isRequesting = false
        }
    }

    private func showToast(message: String, color: Color) {
        toastMessage = message
        toastColor = color
        showToast = true
    }

    private func getTitle() -> String {
        if let nomeUtente {
            return "Ciao \(nomeUtente)"
        }
        return "Home"
    }

    private func getDateString(from scheda: Scheda) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: scheda.dataInizio)
    }

}

private struct HomeErrorState: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(.orange)

            Text("Impossibile caricare la scheda")
                .montserrat(size: 21)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(errorMessage)
                .montserrat(size: 15)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Riprova", action: onRetry)
                .montserrat(size: 17)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HomeEmptyState: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Nessuna scheda disponibile")
                .montserrat(size: 21)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Il tuo trainer non ha ancora pubblicato la scheda.")
                .montserrat(size: 15)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Aggiorna", action: onRetry)
                .montserrat(size: 17)
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActiveSchedaBanner: View {
    let settimaneRimanenti: Int

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Scheda attiva")
                .montserrat(size: 20)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)

            Text(activeMessage)
                .montserrat(size: 17)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .listRowSeparator(.hidden)
    }

    private var activeMessage: String {
        let settimaneLabel = settimaneRimanenti == 1 ? "1 settimana rimanente" : "\(settimaneRimanenti) settimane rimanenti"
        return "\(settimaneLabel). Il cambio scheda sarà disponibile solo quando il conteggio arriva a 0.\nLe modifiche vengono gestite nel weekend: invia la richiesta tra le 20:00 di venerdì e le 10:00 di sabato."
    }
}

private struct ExpiredSchedaBanner: View {
    let cambioRichiesto: Bool
    let isRequesting: Bool
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            Text("⚠️ Scheda scaduta!")
                .montserrat(size: 22)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)

            Text("La scheda è terminata e può essere aggiornata.\nLe modifiche vengono gestite nel weekend: invia la richiesta tra le 20:00 di venerdi e le 10:00 di sabato. Durante la settimana il cambio potrebbe non essere effettuato.")
                .montserrat(size: 17)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if cambioRichiesto {
                Label("Richiesta inviata", systemImage: "checkmark.circle.fill")
                    .montserrat(size: 16)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                RequestSchedaButton(isRequesting: isRequesting, tint: .red, action: onRequest)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowSeparator(.hidden)
    }
}

private struct RequestSchedaButton: View {
    let isRequesting: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isRequesting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                Text("Richiedi nuova scheda")
                    .montserrat(size: 16)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .clipShape(Capsule())
        .disabled(isRequesting)
    }
}

#Preview("Home - Preview Data") {
    let viewModel = SchedaViewModel(autoFetchOnInit: false, scheda: PreviewData.scheda)
    HomeView(schedaViewModel: viewModel, previewUserName: "Matteo")
}
