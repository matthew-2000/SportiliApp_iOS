//
//  AddSchedaView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI
import Firebase

struct AddSchedaView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAlert = false

    var userCode: String
    @ObservedObject var gymViewModel: GymViewModel
    @State private var dataInizio : Date
    @State private var durata : Int
    @State private var scheda: Scheda?
    @State private var giorni: [Giorno]
    
    init(userCode: String, gymViewModel: GymViewModel, dataInizio: Date = Date(), durata: Int = 7, scheda: Scheda?) {
        self.userCode = userCode
        self.gymViewModel = gymViewModel
        if let scheda = scheda {
            self.giorni = scheda.giorni
            self.durata = scheda.durata
            self.dataInizio = scheda.dataInizio
        } else {
            self.durata = durata
            self.dataInizio = dataInizio
            self.giorni = []
        }
    }
    
    var body: some View {
        
        NavigationView {
            Form {
                Section(header: Text("Dettagli Scheda").montserrat(size: 17)) {
                    DatePicker("Data Inizio", selection: $dataInizio, displayedComponents: .date)
                        .montserrat(size: 17)
                    Stepper(value: $durata, in: 1...12) {
                        Text("Durata: \(durata) settimane")
                            .montserrat(size: 17)
                    }
                }
                
                Section(header: Text("Giorni").montserrat(size: 17)) {
                    ForEach(giorni.indices, id: \.self) { giornoIndex in
                        NavigationLink(destination: GiornoDetailView(giorno: $giorni[giornoIndex])) {
                            Text(giorni[giornoIndex].name.isEmpty ? "Nuovo Giorno" : giorni[giornoIndex].name)
                                .montserrat(size: 17)
                        }
                    }
                    .onDelete { indices in
                        giorni.remove(atOffsets: indices)
                    }
                    
                    Button(action: {
                        let nuovoGiorno = Giorno(id: UUID().uuidString, name: "A", gruppiMuscolari: [])
                        giorni.append(nuovoGiorno)
                    }) {
                        Text("Aggiungi Giorno")
                            .montserrat(size: 17)
                    }
                }
                
                
                
                if !giorni.isEmpty {
                    Section {
                        Button(action: {
                            let scheda = Scheda(dataInizio: dataInizio, durata: durata, giorni: giorni)
                            gymViewModel.saveScheda(scheda: scheda, userCode: userCode)
                        }) {
                            Text("Salva Scheda")
                                .montserrat(size: 17)
                        }
                    }
                }
            }
            .navigationTitle(Text("Dettagli Scheda").montserrat(size: 20))
            .navigationBarItems(trailing: Button("Annulla") {
                showingAlert = true
            }
            .montserrat(size: 17))
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Conferma").montserrat(size: 17),
                    message: Text("Sei sicuro di voler chiudere la pagina?").montserrat(size: 15),
                    primaryButton: .default(Text("Resta").montserrat(size: 17)),
                    secondaryButton: .destructive(Text("Chiudi").montserrat(size: 17)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .interactiveDismissDisabled(true) // Disables swipe to dismiss
        }
    }
    
}


#Preview {
    AddSchedaView(userCode: "Pepo", gymViewModel: GymViewModel(), scheda: nil)
}
