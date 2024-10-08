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
                Section(header: Text("Dettagli Scheda")) {
                    DatePicker("Data Inizio", selection: $dataInizio, displayedComponents: .date)
                    Stepper(value: $durata, in: 1...12) {
                        Text("Durata: \(durata) settimane")
                    }
                }
                
                Section(header: Text("Giorni")) {
                    ForEach(giorni.indices, id: \.self) { giornoIndex in
                        NavigationLink(destination: GiornoDetailView(giorno: $giorni[giornoIndex])) {
                            Text(giorni[giornoIndex].name.isEmpty ? "Nuovo Giorno" : giorni[giornoIndex].name)
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
                    }
                }
                
                
                
                if !giorni.isEmpty {
                    Section {
                        Button(action: {
                            let scheda = Scheda(dataInizio: dataInizio, durata: durata, giorni: giorni)
                            gymViewModel.saveScheda(scheda: scheda, userCode: userCode)
                        }) {
                            Text("Salva Scheda")
                        }
                    }
                }
            }
            .navigationTitle("Dettagli Scheda")
            .navigationBarItems(trailing: Button("Annulla") {
                showingAlert = true
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Conferma"),
                    message: Text("Sei sicuro di voler chiudere la pagina?"),
                    primaryButton: .default(Text("Resta")),
                    secondaryButton: .destructive(Text("Chiudi")) {
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
