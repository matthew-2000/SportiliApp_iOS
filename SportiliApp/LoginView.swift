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
    
    @State private var code: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var isFaustoLoggedIn: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            Spacer()
            VStack {
                Image("icon")
                    .resizable()
                    .frame(width: 200, height: 200)
                Text("SportiliApp")
                    .montserrat(size: 30)
                    .bold()
            }
            Spacer()
            
            VStack {
                TextField("Codice", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .montserrat(size: 20)
                    .fontWeight(.semibold)
                    .padding(.bottom, 30)
                
                Button(action: {
                    // Logica per controllare il codice e fare il login
                    if code.isEmpty {
                        self.alertMessage = "Inserisci il codice!"
                        self.showAlert.toggle()
                        return
                    }
                    isAdmin(codice: code, completion: { isAdmin in
                        if !isAdmin {
                            register()
                        } else {
                            loginFausto()
                        }
                    })
                    
                }, label: {
                    Text("Entra")
                        .frame(maxWidth: .infinity)
                })
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Attenzione"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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
        .fullScreenCover(isPresented: $isFaustoLoggedIn) {
            AdminHomeView()
        }
    }
    
    func loginFausto() {
        Auth.auth().signInAnonymously { (authResult, error) in
            if error != nil {
                self.alertMessage = "Errore durante l'accesso. Riprova più tardi."
                self.showAlert.toggle()
            } else {
                UserDefaults.standard.set(true, forKey: "isAdmin")
                isFaustoLoggedIn = true
            }
        }
    }
    
    func register() {
        let db = Database.database().reference().child("users")
        db.observeSingleEvent(of: .value) { snapshot in
            if let authUsers = snapshot.value as? [String: [String: Any]] {
                if let authorizedUser = authUsers[code] {
                    Auth.auth().signInAnonymously { (authResult, error) in
                        if error != nil {
                            self.alertMessage = "Errore durante l'accesso. Riprova più tardi."
                            self.showAlert.toggle()
                        } else {
                            // Utente registrato con successo
                            let changeRequest = authResult?.user.createProfileChangeRequest()
                            changeRequest?.displayName = authorizedUser["nome"] as? String
                            changeRequest?.commitChanges(completion: { (error) in
                                if let error = error {
                                    print("Errore durante l'associazione del nome utente:", error.localizedDescription)
                                    // Gestisci l'errore
                                } else {
                                    print("Nome utente associato con successo:", code)
                                }
                            })
                            UserDefaults.standard.set(code, forKey: "code")
                            self.isLoggedIn = true
                        }
                    }
                } else {
                    // Nome e/o cognome non autorizzati
                    self.alertMessage = "Codice non autorizzato."
                    self.showAlert.toggle()
                }
            } else {
                // Errore nel recupero degli utenti autorizzati
                self.alertMessage = "Errore durante il recupero degli utenti. Riprova più tardi."
                self.showAlert.toggle()
            }
        }
    }
    
    func isAdmin(codice: String, completion: @escaping (Bool) -> Void) {
        let ref = Database.database().reference().child("fausto")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let valore = snapshot.value as? String {
                completion(codice == valore)
            } else {
                completion(false)
            }
        }
    }
    
}


#Preview {
    LoginView()
}
