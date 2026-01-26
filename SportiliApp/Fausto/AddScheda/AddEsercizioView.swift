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
                Section(header: Text("Dettagli Esercizio").montserrat(size: 17)) {
                    TextField("Nome Esercizio", text: $nomeEsercizio)
                        .montserrat(size: 17)
                    
                    Stepper(value: $serieInt, in: 1...30) {
                        Text("\(serieInt) serie")
                            .montserrat(size: 17)
                    }
                    
                    Stepper(value: $ripetizioni, in: 1...50) {
                        Text("\(ripetizioni) ripetizioni")
                            .montserrat(size: 17)
                    }
                }
                
                Section(header: Text("Ripetizioni testuali").montserrat(size: 17)) {
                    TextField("Serie o minuti", text: $serie)
                        .montserrat(size: 17)
                }
                
                Section(header: Text("Altro").montserrat(size: 17)) {
                    TextField("Riposo", text: $riposo)
                        .montserrat(size: 17)
                    TextField("Note PT", text: $notePT)
                        .montserrat(size: 17)
                }
                
                Section {
                    Button(action: aggiungiEsercizio) {
                        Text("Aggiungi")
                            .montserrat(size: 17)
                    }
                    .disabled(nomeEsercizio.isEmpty)
                }
            }
            .navigationTitle(Text("Nuovo Esercizio").montserrat(size: 20))
            .navigationBarItems(trailing: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            }
            .montserrat(size: 17))
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
