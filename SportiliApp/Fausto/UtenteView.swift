//
//  UtenteView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 19/06/24.
//

import SwiftUI

struct UtenteView: View {
    @ObservedObject var gymViewModel: GymViewModel
    @State private var editedNome: String
    @State private var editedCognome: String
    @State private var editedCode: String
    @State private var showEliminaAlert = false
    @State private var showAddSchedaView = false
    var utente: Utente
    
    init(utente: Utente, gymViewModel: GymViewModel) {
        self.utente = utente
        self.gymViewModel = gymViewModel
        self._editedNome = State(initialValue: utente.nome)
        self._editedCognome = State(initialValue: utente.cognome)
        self._editedCode = State(initialValue: utente.code)
    }
    
    var body: some View {
        Form {
            
            Section(header: Text("Codice").montserrat(size: 17), content: {
                Text("\(utente.code)")
                    .montserrat(size: 17)
            })
            
            Section(header: Text("Modifica Utente").montserrat(size: 17)) {
                TextField("Nome", text: $editedNome)
                    .montserrat(size: 17)
                TextField("Cognome", text: $editedCognome)
                    .montserrat(size: 17)
            }
            
            Section(header: Text("Scheda").montserrat(size: 17)) {
                if utente.scheda != nil {
                    Button(action: {
                        showAddSchedaView.toggle()
                    }) {
                        Text("Modifica scheda")
                            .montserrat(size: 17)
                    }
                } else {
                    Button(action: {
                        showAddSchedaView.toggle()
                    }) {
                        Text("Aggiungi scheda")
                            .montserrat(size: 17)
                    }
                }
            }
            
            Section(header: Text("Azioni").montserrat(size: 17)) {
                Button(action: {
                    let updatedUtente = Utente(code: editedCode, cognome: editedCognome, nome: editedNome, scheda: utente.scheda)
                    gymViewModel.updateUser(utente: updatedUtente)
                }) {
                    Text("Salva modifiche")
                        .montserrat(size: 17)
                }
                
                Button(action: {
                    showEliminaAlert = true
                }) {
                    Text("Elimina")
                        .montserrat(size: 17)
                }
                .foregroundColor(.red)
                .buttonStyle(PlainButtonStyle())
            }
            
        }
        .alert(isPresented: $showEliminaAlert) {
            Alert(
                title: Text("Conferma Eliminazione").montserrat(size: 17),
                message: Text("Sei sicuro di voler eliminare questo utente?").montserrat(size: 15),
                primaryButton: .destructive(Text("Elimina").montserrat(size: 17)) {
                    gymViewModel.removeUser(code: utente.code)
                },
                secondaryButton: .cancel(Text("Annulla").montserrat(size: 17))
            )
        }
        .onAppear {
            editedNome = utente.nome
            editedCognome = utente.cognome
            editedCode = utente.code
        }
        .navigationTitle(Text("Modifica Utente").montserrat(size: 20))
        .sheet(isPresented: $showAddSchedaView) {
            AddSchedaView(userCode: utente.code, gymViewModel: gymViewModel, scheda: utente.scheda)
        }
    }
}

#Preview {
    UtenteView(utente: Utente(code: "Boh", cognome: "Boh", nome: "Boh", scheda: nil), gymViewModel: GymViewModel())
}
