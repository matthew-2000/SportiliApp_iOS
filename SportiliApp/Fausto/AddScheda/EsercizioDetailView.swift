//
//  EsercizioDetailView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct EsercizioDetailView: View {
    @Binding var esercizio: Esercizio
    @State private var serieInt: Int
    @State private var ripetizioni: Int
    @State private var customSerie: String = ""
    
    init(esercizio: Binding<Esercizio>) {
        self._esercizio = esercizio
        let serieParts = esercizio.wrappedValue.serie.split(separator: "x").map { String($0) }
        if serieParts.count == 2, let serieInt = Int(serieParts[0]), let ripetizioni = Int(serieParts[1]) {
            self._serieInt = State(initialValue: serieInt)
            self._ripetizioni = State(initialValue: ripetizioni)
        } else {
            self._serieInt = State(initialValue: 3)
            self._ripetizioni = State(initialValue: 10)
        }
        self._customSerie = State(initialValue: esercizio.wrappedValue.serie)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Dettagli Esercizio")) {
                TextField("Nome Esercizio", text: $esercizio.name)
                
                Stepper(value: $serieInt, in: 1...30, step: 1) {
                    Text("\(serieInt) serie")
                }
                .onChange(of: serieInt) { _ in
                    updateSerie()
                }
                
                Stepper(value: $ripetizioni, in: 1...50, step: 1) {
                    Text("\(ripetizioni) ripetizioni")
                }
                .onChange(of: ripetizioni) { _ in
                    updateSerie()
                }
                
            }
            
            Section(header: Text("Ripetizioni testuali"), content: {
                TextField("Serie o minuti", text: $customSerie)
                    .onChange(of: customSerie) { newValue in
                        parseCustomSerie(newValue)
                    }
            })
            
            Section(header: Text("Altro")) {
                TextField("Riposo", text: Binding(
                    get: { esercizio.riposo ?? "" },
                    set: { esercizio.riposo = $0 }
                ))
                
                TextField("Note PT", text: Binding(
                    get: { esercizio.notePT ?? "" },
                    set: { esercizio.notePT = $0 }
                ))
            }
        }
        .navigationTitle("\(esercizio.name)")
    }
    
    private func updateSerie() {
        esercizio.serie = "\(serieInt)x\(ripetizioni)"
    }
    
    private func parseCustomSerie(_ value: String) {
        let parts = value.split(separator: "x").map { String($0) }
        if parts.count == 2, let newSerieInt = Int(parts[0]), let newRipetizioni = Int(parts[1]) {
            serieInt = newSerieInt
            ripetizioni = newRipetizioni
        } else {
            // Handle custom formats or reset to default if parsing fails
            serieInt = 3
            ripetizioni = 10
        }
    }
}
