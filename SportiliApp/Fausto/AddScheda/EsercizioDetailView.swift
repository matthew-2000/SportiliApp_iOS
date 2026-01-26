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
            Section(header: Text("Dettagli Esercizio").montserrat(size: 17)) {
                TextField("Nome Esercizio", text: $esercizio.name)
                    .montserrat(size: 17)
                
                Stepper(value: $serieInt, in: 1...30, step: 1) {
                    Text("\(serieInt) serie")
                        .montserrat(size: 17)
                }
                .onChange(of: serieInt) { _ in
                    updateSerie()
                }
                
                Stepper(value: $ripetizioni, in: 1...50, step: 1) {
                    Text("\(ripetizioni) ripetizioni")
                        .montserrat(size: 17)
                }
                .onChange(of: ripetizioni) { _ in
                    updateSerie()
                }
                
            }
            
            Section(header: Text("Ripetizioni testuali").montserrat(size: 17), content: {
                TextField("Serie o minuti", text: $customSerie)
                    .montserrat(size: 17)
                    .onChange(of: customSerie) { newValue in
                        parseCustomSerie(newValue)
                    }
            })
            
            Section(header: Text("Altro").montserrat(size: 17)) {
                TextField("Riposo", text: Binding(
                    get: { esercizio.riposo ?? "" },
                    set: { esercizio.riposo = $0 }
                ))
                .montserrat(size: 17)
                
                TextField("Note PT", text: Binding(
                    get: { esercizio.notePT ?? "" },
                    set: { esercizio.notePT = $0 }
                ))
                .montserrat(size: 17)
            }
        }
        .navigationTitle(Text("\(esercizio.name)").montserrat(size: 20))
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
