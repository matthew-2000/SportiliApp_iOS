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
    @State private var selectedUser: Utente? = nil
    
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
                            Button(action: {
                                selectedUser = utente
                            }) {
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
        .sheet(item: $selectedUser) { utente in
            UtenteView(utente: utente, gymViewModel: gymViewModel)
        }
    }
}

struct UtenteRow: View {
    var utente: Utente
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(utente.nome) \(utente.cognome)")
                if utente.scheda == nil {
                    Text("Scheda mancante")
                        .underline()
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dati utente")) {
                    TextField("Codice", text: $code)
                    TextField("Nome", text: $nome)
                    TextField("Cognome", text: $cognome)
                }
                
            }
            .navigationTitle("Aggiungi utente")
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Salva") {
                gymViewModel.addUser(code: code, cognome: cognome, nome: nome)
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}


#Preview {
    AdminHomeView()
}
