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
    
    func getDurataScheda() -> Int? {
        // Calcola la data finale aggiungendo il numero di settimane alla data di inizio
        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .weekOfYear, value: durata, to: dataInizio) else {
            return nil
        }
        
        // Calcola la differenza tra la data corrente e la data finale
        let currentDate = Date()
        guard currentDate < endDate else {
            return nil
        }
        
        let components = calendar.dateComponents([.weekOfYear], from: currentDate, to: endDate)
        return components.weekOfYear
    }
    
}


class SchedaManager {

    func getSchedaFromFirebase(code: String, completion: @escaping (Scheda?) -> Void) {
        if Auth.auth().currentUser != nil {
            let ref = Database.database().reference().child("users").child(code).child("scheda")
            
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
                
                var giorni: [Giorno] = []
                for (_, giornoData) in giorniData {
                    if let giornoData = giornoData as? [String: Any] {
                        let nome = giornoData["name"] as? String ?? ""
                        let gruppiMuscolariData = giornoData["gruppiMuscolari"] as? [String: Any] ?? [:]
                        
                        var gruppiMuscolari: [GruppoMuscolare] = []
                        for (_, gruppoData) in gruppiMuscolariData {
                            if let gruppoData = gruppoData as? [String: Any] {
                                let nomeGruppo = gruppoData["nome"] as? String ?? ""
                                let eserciziData = gruppoData["esercizi"] as? [String: Any] ?? [:]
                                
                                var esercizi: [Esercizio] = []
                                for (_, esercizioData) in eserciziData {
                                    if let esercizioData = esercizioData as? [String: Any] {
                                        let nomeEsercizio = esercizioData["name"] as? String ?? ""
                                        let rep = esercizioData["rep"] as? String ?? ""
                                        let serie = esercizioData["serie"] as? String ?? ""
                                        let nota = esercizioData["nota"] as? String
                                        let notaUtente = esercizioData["notaUtente"] as? String
                                        let riposo = esercizioData["riposo"] as? String
                                        
                                        let esercizio = Esercizio(name: nomeEsercizio, rep: rep, serie: serie, riposo: riposo, notePT: nota, noteUtente: notaUtente)
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
