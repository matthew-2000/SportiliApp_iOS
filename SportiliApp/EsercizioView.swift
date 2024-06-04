//
//  EsercizioView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct EsercizioView: View {
    
    var esercizio: Esercizio
    
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
                        Text("\(esercizio.serie)x\(esercizio.rep)")
                            .montserrat(size: 30)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        if let riposo = esercizio.riposo {
                            Text("\(riposo) riposo")
                                .montserrat(size: 18)
                                .fontWeight(.semibold)
                        }
                        VStack(alignment: .leading, content: {
                            Text("Note:")
                                .montserrat(size: 20)
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
                    .montserrat(size: 20)
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
                    
                }, label: {
                    Text("Entra")
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.large)
            }
            
            Spacer()
            
        }
        .padding()
        .navigationTitle(esercizio.name)
        .navigationBarTitleDisplayMode(.large)
    }
    
}
