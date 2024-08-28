//
//  EserciziPredefinitiManager.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 25/06/24.
//

import Foundation
import FirebaseDatabase

struct EsercizioPredefinito: Identifiable {
    var id: String
    var nome: String
    var imageurl: String
}

struct GruppoMuscolarePredefinito: Identifiable {
    var id: String
    var nome: String
    var esercizi: [EsercizioPredefinito]
}

class EserciziPredefinitiViewModel: ObservableObject {
    @Published var gruppiMuscolariPredefiniti: [GruppoMuscolarePredefinito] = []

    private var ref: DatabaseReference!

    init() {
        ref = Database.database().reference()
        fetchWorkoutData()
    }

    func fetchWorkoutData() {
        ref.child("esercizi").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }

            var gruppi = [GruppoMuscolarePredefinito]()

            for (key, data) in value {
                if let dataDict = data as? [String: Any],
                   let eserciziArray = dataDict["esercizi"] as? [[String: String]] {
                    
                    var esercizi = eserciziArray.compactMap { dict -> EsercizioPredefinito? in
                        guard let nome = dict["nome"] else { return nil }
                        return EsercizioPredefinito(id: UUID().uuidString, nome: nome, imageurl: "")
                    }
                    esercizi.sort(by: { (e1, e2) in
                        return e1.nome < e2.nome
                    })
                    let gruppo = GruppoMuscolarePredefinito(id: UUID().uuidString, nome: key, esercizi: esercizi)
                    gruppi.append(gruppo)
                }
            }
            DispatchQueue.main.async {
                self.gruppiMuscolariPredefiniti = gruppi
            }
        }) { error in
            print(error.localizedDescription)
        }
    }
    
    func getGruppoMuscolare(named name: String) -> GruppoMuscolarePredefinito? {
        return gruppiMuscolariPredefiniti.first { $0.nome == name }
    }
}
