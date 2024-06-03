//
//  LoginView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct LoginView: View {
    
    @State private var nome: String = ""
    @State private var cognome: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 10)
                .frame(height: 200)
                .foregroundColor(.cardGray)
            Spacer()
            
            VStack {
                TextField("Nome", text: $nome)
                    .textFieldStyle(.roundedBorder)
                    .montserrat(size: 16)
                TextField("Cognome", text: $cognome)
                    .textFieldStyle(.roundedBorder)
                    .montserrat(size: 16)
                    .padding(.bottom)
                
                Button(action: {
                    // Logica per controllare il codice e fare il login
                    if nome.isEmpty {
                        self.alertMessage = "Inserisci il nome!"
                        self.showAlert.toggle()
                        return
                    }
                    if cognome.isEmpty {
                        self.alertMessage = "Inserisci il cognome!"
                        self.showAlert.toggle()
                        return
                    }
                    register()
                    
                }, label: {
                    Text("Entra")
                        .frame(maxWidth: .infinity)
                })
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Messaggio"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
                .montserrat(size: 20)
                .bold()
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.large)
                
                Button("Hai bisogno di aiuto?", action: {
                    // Azione per gestire il caso in cui l'utente non ha il codice
                })
                .montserrat(size: 15)
                
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $isLoggedIn) {
            ContentView()
        }
    }
    
    func register() {
        // Recupera i dati dall'elenco degli utenti autorizzati
        let db = Database.database().reference().child("authUsers")
        db.observeSingleEvent(of: .value) { snapshot in
            // Controlla se il nome e il cognome inseriti corrispondono a quelli presenti nell'elenco degli utenti autorizzati
            if let authUsers = snapshot.value as? [String: [String: String]] {
                if authUsers.values.first(where: { $0["nome"] == nome && $0["cognome"] == cognome }) != nil {
                    // Effettua il login solo se il nome e il cognome corrispondono a quelli presenti nell'elenco degli utenti autorizzati
                    Auth.auth().signInAnonymously { (authResult, error) in
                        if error != nil {
                            // Gestisci l'errore
                            self.alertMessage = "Errore durante l'accesso. Riprova più tardi."
                            self.showAlert.toggle()
                        } else {
                            // Utente registrato con successo
                            if let uid = authResult?.user.uid {
                                let userData = ["nome": nome, "cognome": cognome] // Puoi aggiungere altri campi dati se necessario
                                Database.database().reference().child("users").child(uid).setValue(userData)
                            }
                            let changeRequest = authResult?.user.createProfileChangeRequest()
                            changeRequest?.displayName = nome
                            changeRequest?.commitChanges(completion: { (error) in
                                if let error = error {
                                    print("Errore durante l'associazione del nome utente:", error.localizedDescription)
                                    // Gestisci l'errore
                                } else {
                                    print("Nome utente associato con successo:", nome)
                                    // Naviga verso la tua schermata principale o fai altre operazioni dopo il login
                                }
                            })
                            self.isLoggedIn = true
                        }
                    }
                } else {
                    // Nome e/o cognome non autorizzati
                    self.alertMessage = "Nome e/o cognome non autorizzati."
                    self.showAlert.toggle()
                }
            } else {
                // Errore nel recupero degli utenti autorizzati
                self.alertMessage = "Errore durante il recupero degli utenti. Riprova più tardi."
                self.showAlert.toggle()
            }
        }
    }
    
}


#Preview {
    LoginView()
}
