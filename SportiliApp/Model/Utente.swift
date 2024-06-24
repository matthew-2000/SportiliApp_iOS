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
                    let giorniData = schedaData["giorni"] as? [String: Any] ?? [:]
                    
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
                            let nomeGiorno = giornoData["name"] as? String ?? ""
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
                            
                            let giorno = Giorno(name: nomeGiorno, gruppiMuscolari: gruppiMuscolari)
                            giorni.append(giorno)
                        }
                    }
                    
                    let scheda = Scheda(dataInizio: dataInizio, durata: durata, giorni: giorni)
                    scheda.sortAll()
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

