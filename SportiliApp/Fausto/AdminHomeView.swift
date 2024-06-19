//
//  AdminHomeView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 04/06/24.
//

import SwiftUI

struct AdminHomeView: View {
    
    @StateObject private var gymViewModel = GymViewModel()
    @State private var searchText = ""
    @State private var showAddUserView = false
    
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
                                
                if let utenti = gymViewModel.users {
                    List {
                        ForEach(utenti.filter { user in
                            searchText.isEmpty ||
                            user.nome.lowercased().contains(searchText.lowercased()) ||
                            user.cognome.lowercased().contains(searchText.lowercased()) ||
                            user.code.lowercased().contains(searchText.lowercased())
                        }, id: \.id) { utente in
                            NavigationLink(destination: UtenteView(utente: utente, gymViewModel: gymViewModel)) {
                                UtenteRow(utente: utente)
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
                
            }
            .searchable(text: $searchText)
            .navigationTitle("Home")
            .toolbar(content: {
                Button(action: {
                    showAddUserView.toggle()
                }) {
                    Image(systemName: "person.badge.plus")
                }
                .padding()
                .sheet(isPresented: $showAddUserView) {
                    AddUserView(gymViewModel: gymViewModel)
                }
            })
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct UtenteRow: View {
    var utente: Utente
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(utente.nome) \(utente.cognome)")
                    .montserrat(size: 18)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
        .padding()
    }
}

struct AddUserView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var gymViewModel: GymViewModel
    @State private var code = ""
    @State private var cognome = ""
    @State private var nome = ""
    @State private var scheda = Scheda(dataInizio: Date(), durata: 4, giorni: [])
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dati utente")) {
                    TextField("Codice", text: $code)
                    TextField("Cognome", text: $cognome)
                    TextField("Nome", text: $nome)
                }
                
                Section(header: Text("Scheda")) {
                    DatePicker("Data Inizio", selection: $scheda.dataInizio, displayedComponents: .date)
                    Stepper(value: $scheda.durata, in: 1...52) {
                        Text("Durata (settimane): \(scheda.durata)")
                    }
                }
            }
            .navigationTitle("Aggiungi Utente")
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Salva") {
                gymViewModel.addUser(code: code, cognome: cognome, nome: nome, scheda: scheda)
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}


#Preview {
    AdminHomeView()
}
