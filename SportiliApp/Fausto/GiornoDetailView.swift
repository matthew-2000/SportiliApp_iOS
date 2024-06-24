//
//  GiornoDetailView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct GiornoDetailView: View {
    @Binding var giorno: Giorno
    
    var body: some View {
        Form {
            Section(header: Text("Nome Giorno")) {
                TextField("Nome Giorno", text: $giorno.name)
            }
            
            Section(header: Text("Gruppi Muscolari")) {
                ForEach($giorno.gruppiMuscolari) { $gruppo in
                    NavigationLink(destination: GruppoMuscolareDetailView(gruppo: $gruppo)) {
                        Text(gruppo.nome.isEmpty ? "Nuovo Gruppo Muscolare" : gruppo.nome)
                    }
                }
                
                Button(action: {
                    let nuovoGruppo = GruppoMuscolare(nome: "", esercizi: [])
                    giorno.gruppiMuscolari.append(nuovoGruppo)
                }) {
                    Text("Aggiungi Gruppo Muscolare")
                }
            }
        }
        .navigationTitle("Dettagli Giorno")
    }
}

struct GiornoDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GiornoDetailView(giorno: .constant(Giorno(name: "Lunedì", gruppiMuscolari: [])))
    }
}
