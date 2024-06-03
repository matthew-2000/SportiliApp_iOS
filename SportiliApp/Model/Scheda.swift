//
//  Scheda.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation
import Firebase

class Scheda {
    
    var dataInizio: Date
    var durata: Int
    var giorni: [Giorno]
    
    init(dataInizio: Date, durata: Int, giorni: [Giorno]) {
        self.dataInizio = dataInizio
        self.durata = durata
        self.giorni = giorni
    }
    
}


class SchedaManager {

    func getSchedaFromFirebase(completion: @escaping (Scheda?) -> Void) {
        if let currentUser = Auth.auth().currentUser {
            let userId = currentUser.uid
            let ref = Database.database().reference().child("users").child(userId).child("schede").child("scheda1")
            
            ref.observeSingleEvent(of: .value) { (snapshot) in
                guard let schedaData = snapshot.value as? [String: Any] else {
                    print("Errore nel recupero dei dati della scheda")
                    completion(nil)
                    return
                }
                
                // Ora puoi utilizzare i dati della scheda come preferisci
                // Esempio: creare un oggetto scheda
                let dataInizioString = schedaData["dataInizio"] as? String ?? ""
                let durata = schedaData["durata"] as? Int ?? 0
                let giorniData = schedaData["giorni"] as? [String: Any] ?? [:]
                
                // Converti la data di inizio da stringa a oggetto Date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                guard let dataInizio = dateFormatter.date(from: dataInizioString) else {
                    print("Errore nel convertire la data di inizio")
                    completion(nil)
                    return
                }
                
                // Esempio di come gestire i giorni
                var giorni: [Giorno] = []
                for (_, giornoData) in giorniData {
                    if let giornoData = giornoData as? [String: Any] {
                        let nome = giornoData["name"] as? String ?? ""
                        let gruppiMuscolariData = giornoData["gruppiMuscolari"] as? [String: Any] ?? [:]
                        
                        // Esempio di come gestire i gruppi muscolari
                        var gruppiMuscolari: [GruppoMuscolare] = []
                        for (_, gruppoData) in gruppiMuscolariData {
                            if let gruppoData = gruppoData as? [String: Any] {
                                let nomeGruppo = gruppoData["nome"] as? String ?? ""
                                let eserciziData = gruppoData["esercizi"] as? [String: Any] ?? [:]
                                
                                // Esempio di come gestire gli esercizi
                                var esercizi: [Esercizio] = []
                                for (_, esercizioData) in eserciziData {
                                    if let esercizioData = esercizioData as? [String: Any] {
                                        let nomeEsercizio = esercizioData["name"] as? String ?? ""
                                        let rep = esercizioData["rep"] as? String ?? ""
                                        let serie = esercizioData["serie"] as? String ?? ""
                                        
                                        let esercizio = Esercizio(name: nomeEsercizio, rep: rep, serie: serie)
                                        esercizi.append(esercizio)
                                    }
                                }
                                
                                let gruppoMuscolare = GruppoMuscolare(nome: nomeGruppo, esericizi: esercizi)
                                gruppiMuscolari.append(gruppoMuscolare)
                            }
                        }
                        
                        let giorno = Giorno(name: nome, gruppiMuscolari: gruppiMuscolari)
                        giorni.append(giorno)
                    }
                }
                
                let scheda = Scheda(dataInizio: dataInizio, durata: durata, giorni: giorni)
                
                // Ora hai la scheda completa pronta per essere utilizzata
                completion(scheda)
            }
        } else {
            completion(nil)
        }
    }

}
