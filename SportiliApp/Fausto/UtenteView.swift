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
    
    var utente: Utente
    
    init(utente: Utente, gymViewModel: GymViewModel) {
        self.utente = utente
        self.gymViewModel = gymViewModel
        self._editedNome = State(initialValue: utente.nome)
        self._editedCognome = State(initialValue: utente.cognome)
        self._editedCode = State(initialValue: utente.code)
    }
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Group {
                    
                    Text("Nome")
                        .foregroundColor(.gray)
                        .montserrat(size: 18)
                    TextField("Nome", text: $editedNome)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .montserrat(size: 18)
                        .padding(.bottom)
                    
                    Text("Cognome")
                        .foregroundColor(.gray)
                        .montserrat(size: 18)
                    TextField("Cognome", text: $editedCognome)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .montserrat(size: 18)
                        .padding(.bottom)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            let updatedUtente = Utente(code: editedCode, cognome: editedCognome, nome: editedNome, scheda: utente.scheda)
                            gymViewModel.updateUser(utente: updatedUtente)
                        }) {
                            Text("Salva modifiche")
                        }
                        .montserrat(size: 20)
                        .bold()
                        .buttonStyle(BorderedProminentButtonStyle())
                        Spacer()
                    }
                }
            }
            .padding()
            
            Spacer()
            
            VStack {
                
                HStack {
                    Button(action: {
                        showEliminaAlert = true
                    }) {
                        Text("Elimina")
                    }
                    .montserrat(size: 20)
                    .bold()
                    .buttonStyle(BorderedProminentButtonStyle())
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
                    
                    Spacer()
                    
                    if utente.scheda == nil {
                        NavigationLink(destination: AddSchedaView(userCode: utente.code, gymViewModel: gymViewModel)) {
                            Text("Aggiungi scheda")
                                .montserrat(size: 20)
                                .bold()
                                .buttonStyle(BorderedProminentButtonStyle())
                        }
                    } else {
                        Button(action: {
                            // TODO:
                        }) {
                            Text("Modifica scheda")
                        }
                        .montserrat(size: 20)
                        .bold()
                        .buttonStyle(BorderedProminentButtonStyle())
                    }
                }
                
            }
            .padding()
        }
        .onAppear {
            editedNome = utente.nome
            editedCognome = utente.cognome
            editedCode = utente.code
        }
        .navigationTitle("Modifica Utente")
    }
}

#Preview {
    UtenteView(utente: Utente(code: "Boh", cognome: "Boh", nome: "Boh", scheda: nil), gymViewModel: GymViewModel())
}
