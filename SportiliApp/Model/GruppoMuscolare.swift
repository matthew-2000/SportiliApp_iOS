//
//  GruppoMuscolare.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class GruppoMuscolare: Identifiable, Codable {
    var id: String
    var nome: String
    var esercizi: [Esercizio]

    init(id: String = UUID().uuidString, nome: String, esercizi: [Esercizio]) {
        self.id = id
        self.nome = nome
        self.esercizi = esercizi
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nome
        case esercizi
    }
    
    var description: String {
        var eserciziDesc = ""
        for esercizio in esercizi {
            eserciziDesc += "\n    \(esercizio.description)"
        }
        
        return """
        GruppoMuscolare {
            id: \(id)
            nome: \(nome)
            esercizi: \(eserciziDesc)
        }
        """
    }
}
