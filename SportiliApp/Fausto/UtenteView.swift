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
            Section(header: Text("Modifica Utente")) {
                TextField("Nome", text: $editedNome)
                TextField("Cognome", text: $editedCognome)
            }
            
            Section(header: Text("Scheda")) {
                if let scheda = utente.scheda {
                    Button(action: {
                        showAddSchedaView.toggle()
                    }) {
                        Text("Modifica scheda")
                    }
                } else {
                    Button(action: {
                        showAddSchedaView.toggle()
                    }) {
                        Text("Aggiungi scheda")
                    }
                }
            }
            
            Section(header: Text("Azioni")) {
                Button(action: {
                    let updatedUtente = Utente(code: editedCode, cognome: editedCognome, nome: editedNome, scheda: utente.scheda)
                    gymViewModel.updateUser(utente: updatedUtente)
                }) {
                    Text("Salva modifiche")
                }
                
                Button(action: {
                    showEliminaAlert = true
                }) {
                    Text("Elimina")
                }
                .foregroundColor(.red)
                .buttonStyle(PlainButtonStyle())
            }
            
        }
        .alert(isPresented: $showEliminaAlert) {
            Alert(
                title: Text("Conferma Eliminazione"),
                message: Text("Sei sicuro di voler eliminare questo utente?"),
                primaryButton: .destructive(Text("Elimina")) {
                    gymViewModel.removeUser(code: utente.code)
                },
                secondaryButton: .cancel(Text("Annulla"))
            )
        }
        .onAppear {
            editedNome = utente.nome
            editedCognome = utente.cognome
            editedCode = utente.code
        }
        .navigationTitle("Modifica Utente")
        .sheet(isPresented: $showAddSchedaView) {
            AddSchedaView(userCode: utente.code, gymViewModel: gymViewModel, scheda: utente.scheda)
        }
    }
}

#Preview {
    UtenteView(utente: Utente(code: "Boh", cognome: "Boh", nome: "Boh", scheda: nil), gymViewModel: GymViewModel())
}
