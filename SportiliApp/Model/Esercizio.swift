//
//  Esercizio.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class Esercizio: Identifiable, Codable {
    var id: String
    var name: String
    var serie: String
    var priorita: Int?
    var riposo: String?
    var notePT: String?
    var noteUtente: String?
    var ordine: Int?

    init(id: String = UUID().uuidString, name: String, serie: String, priorita: Int? = nil, riposo: String? = nil, notePT: String? = nil, noteUtente: String? = nil, ordine: Int? = nil) {
        self.id = id
        self.name = name
        self.serie = serie
        self.priorita = priorita
        self.riposo = riposo
        self.notePT = notePT
        self.noteUtente = noteUtente
        self.ordine = ordine
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case serie
        case priorita
        case riposo
        case notePT
        case noteUtente
        case ordine
    }
    
    
    var description: String {
        return """
        Esercizio {
            id: \(id)
            name: \(name)
            serie: \(serie)
            priorita: \(priorita ?? -1)
            riposo: \(riposo ?? "")
            notePT: \(notePT ?? "")
            noteUtente: \(noteUtente ?? "")
            ordine: \(ordine ?? -1)
        }
        """
    }
    
}
