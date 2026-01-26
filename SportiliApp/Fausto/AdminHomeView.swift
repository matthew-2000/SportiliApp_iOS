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
//                            Button(action: {
//                                selectedUser = utente
//                            }) {
//                                UtenteRow(utente: utente)
//                            }
                            NavigationLink(destination: UtenteView(utente: utente, gymViewModel: gymViewModel), label: {
                                UtenteRow(utente: utente)
                            })
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
            .navigationTitle(Text("Home").montserrat(size: 20))
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
//        .sheet(item: $selectedUser) { utente in
//            UtenteView(utente: utente, gymViewModel: gymViewModel)
//        }
    }
}

struct UtenteRow: View {
    var utente: Utente
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(utente.nome) \(utente.cognome)")
                    .montserrat(size: 17)
                if utente.scheda == nil {
                    Text("Scheda mancante!")
                        .montserrat(size: 15)
                        .underline()
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                } else {
                    if utente.scheda?.getDurataScheda() == nil {
                        Text("Scheda scaduta!")
                            .montserrat(size: 15)
                            .underline()
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
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
                Section(header: Text("Dati utente").montserrat(size: 17)) {
                    TextField("Codice", text: $code)
                        .montserrat(size: 17)
                    TextField("Nome", text: $nome)
                        .montserrat(size: 17)
                    TextField("Cognome", text: $cognome)
                        .montserrat(size: 17)
                }
                
            }
            .navigationTitle(Text("Aggiungi utente").montserrat(size: 20))
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Salva") {
                gymViewModel.addUser(code: code, cognome: cognome, nome: nome)
                presentationMode.wrappedValue.dismiss()
            })
            .montserrat(size: 17)
        }
    }
}


#Preview {
    AdminHomeView()
}
