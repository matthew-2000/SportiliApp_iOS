//
//  Utente.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 04/06/24.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase

class Utente {
    var id = UUID()
    var code: String
    var cognome: String
    var nome: String
    var scheda: Scheda
    
    init(id: UUID = UUID(), code: String, cognome: String, nome: String, scheda: Scheda) {
        self.id = id
        self.code = code
        self.cognome = cognome
        self.nome = nome
        self.scheda = scheda
    }
}

class ListaUtenti {
    var utenti: [Utente]
    
    init(utenti: [Utente]) {
        self.utenti = utenti
    }
    
    func ordinaLista() {
        utenti.sort(by: {
            $0.nome < $1.nome
        })
    }
}

class ListaUtentiManager {
    
    func fetchAllUsers(completion: @escaping (ListaUtenti?) -> Void) {
        if Auth.auth().currentUser != nil {
            let ref = Database.database().reference().child("users")
            
            ref.observe(.value) { (snapshot) in
                guard let usersData = snapshot.value as? [String: Any] else {
                    print("Errore nel recupero dei dati degli utenti")
                    completion(nil)
                    return
                }
                
                var utenti: [Utente] = []
                let dispatchGroup = DispatchGroup()
                let schedaManager = SchedaManager()
                
                for (code, userData) in usersData {
                    if let userData = userData as? [String: Any] {
                        let cognome = userData["cognome"] as? String ?? ""
                        let nome = userData["nome"] as? String ?? ""
                        
                        guard let schedaData = userData["scheda"] as? [String : Any] else {
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
                                                let serie = esercizioData["serie"] as? String ?? ""
                                                let nota = esercizioData["nota"] as? String
                                                let notaUtente = esercizioData["notaUtente"] as? String
                                                let riposo = esercizioData["riposo"] as? String
                                                let ordine = esercizioData["ordine"] as? Int
                                                
                                                let esercizio = Esercizio(name: nomeEsercizio, serie: serie, riposo: riposo, notePT: nota, noteUtente: notaUtente, ordine: ordine)
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
                        scheda.sortAll()
                        
                        let utente = Utente(code: code, cognome: cognome, nome: nome, scheda: scheda)
                        utenti.append(utente)

                    }
                }
                
                let listaUtenti = ListaUtenti(utenti: utenti)
                listaUtenti.ordinaLista()
                completion(listaUtenti)
            }
        } else {
            completion(nil)
        }
    }
    
}
