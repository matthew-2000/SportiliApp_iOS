//
//  EsercizioView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI
import FirebaseDatabase

struct EsercizioView: View {
    
    var esercizio: Esercizio
    @State private var showingAlert = false
    @State private var nota: String
    
    init(esercizio: Esercizio, showingAlert: Bool = false, nota: String = "") {
        self.esercizio = esercizio
        self.showingAlert = showingAlert
        self.nota = esercizio.noteUtente ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            
            ZStack {
                
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.cardGray)
                
                VStack(alignment: .leading) {
                    
                    RoundedRectangle(cornerRadius: 5)
                        .frame(height: 150)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(esercizio.serie)")
                            .montserrat(size: 30)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        if let riposo = esercizio.riposo {
                            Text("\(riposo) riposo")
                                .montserrat(size: 20)
                        }
                        VStack(alignment: .leading, content: {
                            Text("Note:")
                                .montserrat(size: 15)
                                .fontWeight(.bold)
                            if let notePT = esercizio.notePT {
                                Text(notePT)
                                    .montserrat(size: 15)
                            } else {
                                Text("Nessuna nota.")
                                    .montserrat(size: 15)
                            }
                        })
                    }

                }
                .padding()
            }
            
            VStack(alignment: .leading) {
                Text("Note utente:")
                    .montserrat(size: 15)
                    .fontWeight(.bold)
                if let noteUtente = esercizio.noteUtente {
                    Text(noteUtente)
                        .montserrat(size: 15)
                } else {
                    Text("Nessuna nota.")
                        .montserrat(size: 15)
                }
                Spacer()
                Button(action: {
                    showingAlert.toggle()
                }, label: {
                    Text("Aggiungi Nota")
                        .frame(maxWidth: .infinity)
                })
                .montserrat(size: 18)
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.large)
                .alert("Inserisci nota:", isPresented: $showingAlert) {
                    TextField("Inserisci nota", text: $nota)
                        .montserrat(size: 15)
                    Button(action: addNota, label: {
                        Text("Inserisci")
                    })
                    .montserrat(size: 15)
                        
                } message: {
                    Text("Inserisci una nota per questo esercizio")
                        .montserrat(size: 15)
                }
            }
            
            Spacer()
            
        }
        .padding()
        .navigationTitle(esercizio.name)
        .navigationBarTitleDisplayMode(.large)
    }
    
    func addNota() {
        
//        guard UserDefaults.standard.string(forKey: "code") != nil else {
//            return
//        }
                
    }
    
}
