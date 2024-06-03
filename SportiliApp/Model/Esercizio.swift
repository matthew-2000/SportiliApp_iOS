//
//  Esercizio.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class Esercizio {
    
    let id = UUID()
    var name: String
    var rep: String
    var serie: String
    var priorità: Int?
    var riposo: String?
    var notePT: String?
    var noteUtente: String?
    
    init(name: String, rep: String, serie: String, priorità: Int? = nil, riposo: String? = nil, notePT: String? = nil, noteUtente: String? = nil) {
        self.name = name
        self.rep = rep
        self.serie = serie
        self.priorità = priorità
        self.riposo = riposo
        self.notePT = notePT
        self.noteUtente = noteUtente
    }
    
}
