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
    @StateObject var imageLoader = ImageLoader()
    
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
                    
                    if let image = imageLoader.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .cornerRadius(5)
                    } else {
                        if imageLoader.error != nil {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .frame(height: 200)
                                    .foregroundColor(.no)
                                
                                Text("Immagine non disponibile")
                                    .montserrat(size: 20)
                                
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .frame(height: 200)
                                    .foregroundColor(.no)
                                
                                // Visualizza uno spinner o un messaggio di caricamento
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                                
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(esercizio.serie)")
                            .montserrat(size: 30)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        if let riposo = esercizio.riposo {
                            if !riposo.isEmpty {
                                Text("\(riposo) riposo")
                                    .montserrat(size: 20)
                            }
                        }
                        VStack(alignment: .leading, content: {
                            Text("Note:")
                                .montserrat(size: 15)
                                .fontWeight(.bold)
                            if let notePT = esercizio.notePT {
                                if !notePT.isEmpty {
                                    Text(notePT)
                                        .montserrat(size: 15)
                                } else {
                                    Text("Nessuna nota.")
                                        .montserrat(size: 15)
                                }
                            } else {
                                Text("Nessuna nota.")
                                    .montserrat(size: 15)
                            }
                        })
                    }
                    
                    Spacer()

                }
                .padding()
            }
            
//            VStack(alignment: .leading) {
//                Text("Note utente:")
//                    .montserrat(size: 15)
//                    .fontWeight(.bold)
//                if let noteUtente = esercizio.noteUtente {
//                    Text(noteUtente)
//                        .montserrat(size: 15)
//                } else {
//                    Text("Nessuna nota.")
//                        .montserrat(size: 15)
//                }
//                Spacer()
//                Button(action: {
//                    showingAlert.toggle()
//                }, label: {
//                    Text("Aggiungi Nota")
//                        .frame(maxWidth: .infinity)
//                })
//                .montserrat(size: 18)
//                .buttonStyle(BorderedProminentButtonStyle())
//                .controlSize(.large)
//                .alert("Inserisci nota:", isPresented: $showingAlert) {
//                    TextField("Inserisci nota", text: $nota)
//                        .montserrat(size: 15)
//                    Button(action: addNota, label: {
//                        Text("Inserisci")
//                    })
//                    .montserrat(size: 15)
//                        
//                } message: {
//                    Text("Inserisci una nota per questo esercizio")
//                        .montserrat(size: 15)
//                }
//            }
            
            Spacer()
            
        }
        .onAppear {
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(esercizio.name).png"
            imageLoader.loadImage(from: storagePath)
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
