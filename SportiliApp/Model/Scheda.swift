//
//  Scheda.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation
import Firebase

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter
}()

class Scheda: Codable {
    var dataInizio: Date
    var durata: Int
    var giorni: [Giorno]

    init(dataInizio: Date, durata: Int, giorni: [Giorno]) {
        self.dataInizio = dataInizio
        self.durata = durata
        self.giorni = giorni
    }

    enum CodingKeys: String, CodingKey {
        case dataInizio
        case durata
        case giorni
    }
    
    var description: String {
        var giorniDesc = ""
        for giorno in giorni {
            giorniDesc += "\n    \(giorno.description)"
        }
        
        return """
        Scheda {
            dataInizio: \(dataInizio)
            durata: \(durata)
            giorni: \(giorniDesc)
        }
        """
    }
    
    func toDictionary() -> [String: Any] {
        var giorniDict = [String: Any]()
        
        for (giornoIndex, giorno) in giorni.enumerated() {
            var gruppiMuscolariDict = [String: Any]()
            
            for (gruppoIndex, gruppo) in giorno.gruppiMuscolari.enumerated() {
                var eserciziDict = [String: Any]()
                
                for (esercizioIndex, esercizio) in gruppo.esercizi.enumerated() {
                    let esercizioDict: [String: Any] = [
                        "name": esercizio.name,
                        "ordine": esercizio.ordine ?? 0,
                        "riposo": esercizio.riposo ?? "",
                        "serie": esercizio.serie,
                        "notePT" : esercizio.notePT ?? ""
                        // Include other properties as needed
                    ]
                    eserciziDict["esercizio\(esercizioIndex + 1)"] = esercizioDict
                }
                
                let gruppoDict: [String: Any] = [
                    "nome": gruppo.nome,
                    "esercizi": eserciziDict
                ]
                gruppiMuscolariDict["gruppo\(gruppoIndex + 1)"] = gruppoDict
            }
            
            let giornoDict: [String: Any] = [
                "name": giorno.name,
                "gruppiMuscolari": gruppiMuscolariDict
            ]
            giorniDict["giorno\(giornoIndex + 1)"] = giornoDict
        }
        
        let schedaDict: [String: Any] = [
            "dataInizio": dateFormatter.string(from: dataInizio),
            "durata": durata,
            "giorni": giorniDict
        ]
        
        return schedaDict
    }
    
    func sortAll() {
        self.giorni.sort(by: {
            $0.name < $1.name
        })
        for giorno in giorni {
            for gruppo in giorno.gruppiMuscolari {
                gruppo.esercizi.sort(by: {
                    $0.ordine ?? 0 < $1.ordine ?? 0
                })
            }
        }
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
                        
            ref.observe(.value) { (snapshot) in
                guard let schedaData = snapshot.value as? [String: Any] else {
                    print("Errore nel recupero dei dati della scheda")
                    completion(nil)
                    return
                }
                
                // Ora puoi utilizzare i dati della scheda come preferisci
                // Esempio: creare un oggetto scheda
                let dataInizioString = schedaData["dataInizio"] as? String ?? ""
                let durata = schedaData["durata"] as? Int ?? 0
                var giorniData = schedaData["giorni"] as? [String: Any] ?? [:]
                
                // Converti la data di inizio da stringa a oggetto Date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                guard let dataInizio = dateFormatter.date(from: dataInizioString) else {
                    print("Errore nel convertire la data di inizio")
                    completion(nil)
                    return
                }
                
                var giorni: [Giorno] = []
                
                // Ordinare giorniData per chiave
                let giorniOrdinati = giorniData.sorted { $0.key < $1.key }
                
                for (_, giornoData) in giorniOrdinati {
                    if let giornoData = giornoData as? [String: Any] {
                        let nome = giornoData["name"] as? String ?? ""
                        var gruppiMuscolariData = giornoData["gruppiMuscolari"] as? [String: Any] ?? [:]
                        
                        var gruppiMuscolari: [GruppoMuscolare] = []
                        
                        // Ordinare gruppiMuscolariData per chiave
                        let gruppiMuscolariOrdinati = gruppiMuscolariData.sorted { $0.key < $1.key }
                        
                        for (_, gruppoData) in gruppiMuscolariOrdinati {
                            if let gruppoData = gruppoData as? [String: Any] {
                                let nomeGruppo = gruppoData["nome"] as? String ?? ""
                                let eserciziData = gruppoData["esercizi"] as? [String: Any] ?? [:]
                                
                                var esercizi: [Esercizio] = []
                                
                                // Ordinare eserciziData per chiave
                                let eserciziOrdinati = eserciziData.sorted { $0.key < $1.key }
                                
                                for (_, esercizioData) in eserciziOrdinati {
                                    if let esercizioData = esercizioData as? [String: Any] {
                                        let nomeEsercizio = esercizioData["name"] as? String ?? ""
                                        let serie = esercizioData["serie"] as? String ?? ""
                                        let nota = esercizioData["nota"] as? String
                                        let notaUtente = esercizioData["notaUtente"] as? String
                                        let riposo = esercizioData["riposo"] as? String
                                        let ordine = esercizioData["ordine"] as? Int
                                        
                                        let esercizio = Esercizio(name: nomeEsercizio, serie: serie, riposo: riposo, notePT: nota, noteUtente: notaUtente, ordine: ordine)
                                        esercizi.append(esercizio)
                                    }
                                }
                                
                                let gruppoMuscolare = GruppoMuscolare(nome: nomeGruppo, esercizi: esercizi)
                                gruppiMuscolari.append(gruppoMuscolare)
                            }
                        }
                        
                        let giorno = Giorno(name: nome, gruppiMuscolari: gruppiMuscolari)
                        giorni.append(giorno)
                    }
                }
                
                let scheda = Scheda(dataInizio: dataInizio, durata: durata, giorni: giorni)
                scheda.sortAll()
                
                completion(scheda)
            }
        } else {
            completion(nil)
        }

    }

}
