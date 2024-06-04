//
//  Utente.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 04/06/24.
//

import Foundation

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
}

class UtentiManager {
    
}
