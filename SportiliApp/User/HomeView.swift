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
    @StateObject private var schedaViewModel = SchedaViewModel()
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastColor: Color = .green
    @State private var isRequesting = false
    
    init() {
        // Set the appearance of the navigation bar title
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.font : UIFont(name: "Montserrat-SemiBold", size: 18)!]
        appearance.largeTitleTextAttributes = [.font : UIFont(name: "Montserrat-Bold", size: 35)!]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                Spacer()
                
                if let scheda = schedaViewModel.scheda {
                    List {
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text("Inizio: \(getDateString())")
                                .montserrat(size: 20)
                                .fontWeight(.semibold)
                            Text("x\(scheda.durata) sett.")
                                .montserrat(size: 25)
                                .foregroundColor(.accentColor)
                                .bold()
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        
                        if let settimaneRimanenti = scheda.getDurataScheda() {
                            if settimaneRimanenti < 2 {
                                // ⚠️ Avviso: in scadenza
                                VStack(spacing: 12) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)

                                    Text("⏳ Scheda in scadenza!")
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(.orange)
                                        .multilineTextAlignment(.center)

                                    Text("Manca solo \(settimaneRimanenti) sett. alla scadenza.\nPuoi già richiedere un aggiornamento.")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)

                                    if scheda.cambioRichiesto {
                                        // Stato già richiesto
                                        Label("Richiesta inviata", systemImage: "checkmark.circle.fill")
                                            .font(.callout.weight(.semibold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.green.opacity(0.15))
                                            .clipShape(Capsule())
                                    } else {
                                        Button(action: {
                                            guard !isRequesting else { return }
                                            isRequesting = true
                                            if let code = UserDefaults.standard.string(forKey: "code") {
                                                SchedaManager().richiediCambioScheda(code: code) { success in
                                                    // Toast
                                                    toastMessage = success ? "Richiesta inviata ✅" : "Errore durante la richiesta ❌"
                                                    toastColor = success ? .green : .red
                                                    showToast = true
                                                    // Refresh UI per riflettere cambioRichiesto = true
                                                    if success { schedaViewModel.fetchScheda() }
                                                    isRequesting = false
                                                }
                                            } else {
                                                toastMessage = "Codice utente mancante ❌"
                                                toastColor = .red
                                                showToast = true
                                                isRequesting = false
                                            }
                                        }) {
                                            if isRequesting {
                                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                            } else {
                                                Text("Richiedi nuova scheda")
                                                    .font(.callout.weight(.semibold))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .clipShape(Capsule())
                                        .disabled(isRequesting)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            }
                        } else {
                            // 🚨 Scheda scaduta
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

                                if scheda.cambioRichiesto {
                                    // Stato già richiesto
                                    Label("Richiesta inviata", systemImage: "checkmark.circle.fill")
                                        .font(.callout.weight(.semibold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.green.opacity(0.15))
                                        .clipShape(Capsule())
                                } else {
                                    Button(action: {
                                        guard !isRequesting else { return }
                                        isRequesting = true
                                        if let code = UserDefaults.standard.string(forKey: "code") {
                                            SchedaManager().richiediCambioScheda(code: code) { success in
                                                // Toast
                                                toastMessage = success ? "Richiesta inviata ✅" : "Errore durante la richiesta ❌"
                                                toastColor = success ? .green : .red
                                                showToast = true
                                                // Refresh UI per riflettere cambioRichiesto = true
                                                if success { schedaViewModel.fetchScheda() }
                                                isRequesting = false
                                            }
                                        } else {
                                            toastMessage = "Codice utente mancante ❌"
                                            toastColor = .red
                                            showToast = true
                                            isRequesting = false
                                        }
                                    }) {
                                        if isRequesting {
                                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                                                .padding(.horizontal, 16).padding(.vertical, 8)
                                        } else {
                                            Text("Richiedi nuova scheda")
                                                .font(.callout.weight(.semibold))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .clipShape(Capsule())
                                    .disabled(isRequesting)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                        
                        ForEach(scheda.giorni, id: \.id) { giorno in
                            NavigationLink(destination: DayView(day: giorno)) {
                                DayRow(day: giorno)
                            }
                        }
                        

                    }
                    .listStyle(PlainListStyle())
                    .onAppear {
                        UITableView.appearance().separatorStyle = .none
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                }
                
                Spacer()
                
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
            .onAppear {
                // Aggiorna il nome utente quando la vista appare per la prima volta
                if let currentUser = Auth.auth().currentUser {
                    nomeUtente = currentUser.displayName
                }
            }
            .navigationTitle(getTitle())
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    func getTitle() -> String {
        if let nomeUtente = nomeUtente {
            return "Ciao \(nomeUtente)"
        } else {
            return "Home"
        }
    }
    
    func getDateString() -> String {
        let formatter1 = DateFormatter()
        formatter1.dateStyle = .short
        return formatter1.string(from: schedaViewModel.scheda?.dataInizio ?? Date())
    }
}

struct DayRow: View {
    var day: Giorno
    
    var body: some View {
        HStack {
            
            VStack(alignment: .leading) {
                Text("\(day.name)")
                    .montserrat(size: 20)
                    .fontWeight(.semibold)
                Text(getGruppiString())
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
        }
        .padding()
    }
    
    func getGruppiString() -> String {
        var s = ""
        for g in day.gruppiMuscolari {
            s += "\(g.nome), "
        }
        return String(s.dropLast(2))
    }
}
