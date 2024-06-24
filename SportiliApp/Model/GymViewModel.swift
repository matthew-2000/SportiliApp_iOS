//
//  GymViewModel.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 17/06/24.
//

import Combine
import FirebaseDatabase

class GymViewModel: ObservableObject {
    @Published var users: [Utente]?
    private var ref: DatabaseReference!
    private var userManager: UserManager
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()


    init() {
        ref = Database.database().reference()
        userManager = UserManager()
        fetchUsers()
    }

    func fetchUsers() {
        ref.child("users").observe(.value) { snapshot in
            var newUsers: [Utente] = []
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot {
                    let userCode = snapshot.key
                    self.userManager.getUserFromFirebase(code: userCode) { user in
                        if let user = user {
                            newUsers.append(user)
                            print(user.description)
                            newUsers.sort { (user1, user2) -> Bool in
                                if user1.scheda != nil && user2.scheda == nil {
                                    return false // user1 con scheda viene prima
                                } else if user1.scheda == nil && user2.scheda != nil {
                                    return true // user2 con scheda viene prima
                                } else {
                                    return user1.nome < user2.nome
                                }
                            }
                            self.users = newUsers
                        }
                    }
                }
            }
        }
    }

    func addUser(code: String, cognome: String, nome: String) {
        ref.child("users").child(code).observe(.value, with: { snapshot in
            if !snapshot.exists() {
                let userDict: [String: Any] = [
                    "cognome": cognome,
                    "nome": nome,
                ]
                
                self.ref.child("users").child(code).setValue(userDict) { error, _ in
                    if let error = error {
                        print("Error adding user: \(error.localizedDescription)")
                    } else {
                        print("User added successfully")
                    }
                }
            }
        })
    }
    
    func removeUser(code: String) {
        ref.child("users").child(code).removeValue { error, _ in
            if let error = error {
                print("Error removing user: \(error.localizedDescription)")
            } else {
                print("User removed successfully")
            }
        }
    }

    func updateUser(utente: Utente) {
        let userDict: [String: Any] = [
            "cognome": utente.cognome,
            "nome": utente.nome,
            "scheda": utente.scheda?.toDictionary() ?? [:]
        ]
        
        ref.child("users").child(utente.code).setValue(userDict) { error, _ in
            if let error = error {
                print("Error adding user: \(error.localizedDescription)")
            } else {
                print("User added successfully")
            }
        }
    }
    
    func saveScheda(scheda: Scheda, userCode: String) {
        let schedaDict = scheda.toDictionary()
        
        let ref = Database.database().reference().child("users").child(userCode).child("scheda")
        
        ref.setValue(schedaDict) { error, _ in
            if let error = error {
                print("Errore nel salvataggio della scheda: \(error.localizedDescription)")
            } else {
                print("Scheda salvata con successo")
            }
        }
    }
}
