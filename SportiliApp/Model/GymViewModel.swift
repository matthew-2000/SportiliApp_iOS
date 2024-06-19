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
                            self.users = newUsers
                        }
                    }
                }
            }
        }
    }

    func addUser(code: String, cognome: String, nome: String, scheda: Scheda) {
        let userDict: [String: Any] = [
            "cognome": cognome,
            "nome": nome,
            "scheda": scheda.toDictionary()
        ]
        
        ref.child("users").child(code).setValue(userDict) { error, _ in
            if let error = error {
                print("Error adding user: \(error.localizedDescription)")
            } else {
                print("User added successfully")
            }
        }
    }

    func updateUser(utente: Utente) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            let data = try encoder.encode(utente)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                ref.child("users").child(utente.code).setValue(json)
            }
        } catch {
            print("Error updating user: \(error)")
        }
    }
}

extension Encodable {
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}
