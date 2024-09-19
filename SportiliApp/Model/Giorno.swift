//
//  Giorno.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class Giorno: Identifiable, Codable {
    var id: String
    var name: String
    var gruppiMuscolari: [GruppoMuscolare]

    init(id: String, name: String, gruppiMuscolari: [GruppoMuscolare]) {
        self.id = id
        self.name = name
        self.gruppiMuscolari = gruppiMuscolari
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case gruppiMuscolari
    }
    
    var description: String {
        var gruppiDesc = ""
        for gruppo in gruppiMuscolari {
            gruppiDesc += "\n    \(gruppo.description)"
        }
        
        return """
        Giorno {
            id: \(id)
            name: \(name)
            gruppiMuscolari: \(gruppiDesc)
        }
        """
    }
}
