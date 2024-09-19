//
//  Utente.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 04/06/24.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase

class Utente: Identifiable, Codable {
    var id = UUID()
    var code: String
    var cognome: String
    var nome: String
    var scheda: Scheda?
    
    init(code: String, cognome: String, nome: String, scheda: Scheda?) {
        self.code = code
        self.cognome = cognome
        self.nome = nome
        self.scheda = scheda
    }

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case cognome
        case nome
        case scheda
    }
    
    var description: String {
        return """
        Utente {
            id: \(id)
            code: \(code)
            cognome: \(cognome)
            nome: \(nome)
            scheda: \(scheda?.description ?? "nil")
        }
        """
    }
}

class UserManager {

    func getUserFromFirebase(code: String, completion: @escaping (Utente?) -> Void) {
        if Auth.auth().currentUser != nil {
            let ref = Database.database().reference().child("users").child(code)
            
            ref.observe(.value) { (snapshot) in
                guard let userData = snapshot.value as? [String: Any] else {
                    print("Errore nel recupero dei dati dell'utente")
                    completion(nil)
                    return
                }
                
                let cognome = userData["cognome"] as? String ?? ""
                let nome = userData["nome"] as? String ?? ""
                
                if let schedaData = userData["scheda"] as? [String: Any] {
                    // Decodifica la scheda
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
                    
                    for (keyGiorno, giornoData) in giorniOrdinati {
                        if let giornoData = giornoData as? [String: Any] {
                            let nome = giornoData["name"] as? String ?? ""
                            var gruppiMuscolariData = giornoData["gruppiMuscolari"] as? [String: Any] ?? [:]
                            
                            var gruppiMuscolari: [GruppoMuscolare] = []
                            
                            // Ordinare gruppiMuscolariData per chiave
                            let gruppiMuscolariOrdinati = gruppiMuscolariData.sorted { $0.key < $1.key }
                            
                            for (keyGruppo, gruppoData) in gruppiMuscolariOrdinati {
                                if let gruppoData = gruppoData as? [String: Any] {
                                    let nomeGruppo = gruppoData["nome"] as? String ?? ""
                                    let eserciziData = gruppoData["esercizi"] as? [String: Any] ?? [:]
                                    
                                    var esercizi: [Esercizio] = []
                                    
                                    // Ordinare eserciziData per chiave
                                    let eserciziOrdinati = eserciziData.sorted { $0.key < $1.key }
                                    
                                    for (keyEse, esercizioData) in eserciziOrdinati {
                                        if let esercizioData = esercizioData as? [String: Any] {
                                            let nomeEsercizio = esercizioData["name"] as? String ?? ""
                                            let serie = esercizioData["serie"] as? String ?? ""
                                            let nota = esercizioData["notePT"] as? String
                                            let noteUtente = esercizioData["noteUtente"] as? String
                                            let riposo = esercizioData["riposo"] as? String
                                            
                                            let esercizio = Esercizio(id: keyEse, name: nomeEsercizio, serie: serie, riposo: riposo, notePT: nota, noteUtente: noteUtente)
                                            esercizi.append(esercizio)
                                        }
                                    }
                                    
                                    let gruppoMuscolare = GruppoMuscolare(id: keyGruppo, nome: nomeGruppo, esercizi: esercizi)
                                    gruppiMuscolari.append(gruppoMuscolare)
                                }
                            }
                            
                            let giorno = Giorno(id: keyGiorno, name: nome, gruppiMuscolari: gruppiMuscolari)
                            giorni.append(giorno)
                        }
                    }
                    
                    let scheda = Scheda(dataInizio: dataInizio, durata: durata, giorni: giorni)
                    let utente = Utente(code: code, cognome: cognome, nome: nome, scheda: scheda)
                    completion(utente)
                    
                } else {
                    let utente = Utente(code: code, cognome: cognome, nome: nome, scheda: nil)
                    completion(utente)
                }

            }
        } else {
            completion(nil)
        }
    }
}

