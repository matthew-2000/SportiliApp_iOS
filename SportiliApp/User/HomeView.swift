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
        configureNavigationBarAppearance()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let scheda = schedaViewModel.scheda {
                    List {
                        header(for: scheda)

                        if let settimaneRimanenti = scheda.getDurataScheda(), settimaneRimanenti < 2 {
                            ExpiringSchedaBanner(
                                settimaneRimanenti: settimaneRimanenti,
                                cambioRichiesto: scheda.cambioRichiesto,
                                isRequesting: isRequesting,
                                tint: .orange,
                                onRequest: requestSchedaUpdate
                            )
                        } else if scheda.getDurataScheda() == nil {
                            ExpiredSchedaBanner(
                                cambioRichiesto: scheda.cambioRichiesto,
                                isRequesting: isRequesting,
                                onRequest: requestSchedaUpdate
                            )
                        }

                        ForEach(scheda.giorni, id: \.id) { giorno in
                            NavigationLink(destination: DayView(day: giorno)) {
                                DayRow(day: giorno)
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .onAppear {
                        UITableView.appearance().separatorStyle = .none
                    }
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
            .navigationTitle(getTitle())
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func header(for scheda: Scheda) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Inizio: \(getDateString(from: scheda))")
                .montserrat(size: 20)
                .fontWeight(.semibold)
            Text("x\(scheda.durata) sett.")
                .montserrat(size: 25)
                .foregroundColor(.accentColor)
                .bold()
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

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.font: navigationTitleFont]
        appearance.largeTitleTextAttributes = [.font: navigationLargeTitleFont]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }

    private var navigationTitleFont: UIFont {
        UIFont(name: "Montserrat-SemiBold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
    }

    private var navigationLargeTitleFont: UIFont {
        UIFont(name: "Montserrat-Bold", size: 35) ?? .systemFont(ofSize: 35, weight: .bold)
    }
}

private struct ExpiringSchedaBanner: View {
    let settimaneRimanenti: Int
    let cambioRichiesto: Bool
    let isRequesting: Bool
    let tint: Color
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 40))
                .foregroundColor(tint)

            Text("⏳ Scheda in scadenza!")
                .font(.title3.weight(.bold))
                .foregroundColor(tint)
                .multilineTextAlignment(.center)

            Text("Manca solo \(settimaneRimanenti) sett. alla scadenza.\nPuoi già richiedere un aggiornamento.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if cambioRichiesto {
                Label("Richiesta inviata", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                RequestSchedaButton(isRequesting: isRequesting, tint: tint, action: onRequest)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .listRowSeparator(.hidden)
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
                .font(.title2.weight(.bold))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)

            Text("Richiedi un aggiornamento al tuo personal trainer.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if cambioRichiesto {
                Label("Richiesta inviata", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
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
                    .font(.callout.weight(.semibold))
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
