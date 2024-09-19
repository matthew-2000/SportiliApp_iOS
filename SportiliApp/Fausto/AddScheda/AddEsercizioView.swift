//
//  AddEsercizioView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct AddEsercizioView: View {
    @Binding var gruppo: GruppoMuscolare
    @Environment(\.presentationMode) var presentationMode
    
    @State var nomeEsercizio = ""
    @State private var serie = ""
    @State private var riposo = ""
    @State private var notePT = ""
    @State private var serieInt = 3
    @State private var ripetizioni = 10
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Esercizio")) {
                    TextField("Nome Esercizio", text: $nomeEsercizio)
                    
                    Stepper(value: $serieInt, in: 1...30) {
                        Text("\(serieInt) serie")
                    }
                    
                    Stepper(value: $ripetizioni, in: 1...50) {
                        Text("\(ripetizioni) ripetizioni")
                    }
                }
                
                Section(header: Text("Ripetizioni testuali")) {
                    TextField("Serie o minuti", text: $serie)
                }
                
                Section(header: Text("Altro")) {
                    TextField("Riposo", text: $riposo)
                    TextField("Note PT", text: $notePT)
                }
                
                Section {
                    Button(action: aggiungiEsercizio) {
                        Text("Aggiungi")
                    }
                    .disabled(nomeEsercizio.isEmpty)
                }
            }
            .navigationTitle("Nuovo Esercizio")
            .navigationBarItems(trailing: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func aggiungiEsercizio() {
        
        let serie = getSerie()
        
        let nuovoEsercizio = Esercizio(id: UUID().uuidString, name: nomeEsercizio, serie: serie, riposo: riposo, notePT: notePT)
        gruppo.esercizi.append(nuovoEsercizio)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func getSerie() -> String {
        if serie.isEmpty {
            return "\(serieInt)x\(ripetizioni)"
        } else {
            return serie
        }
    }
}
