//
//  EsercizioView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI
import FirebaseDatabase
import AVFoundation
import UIKit
import SwiftToast

struct EsercizioView: View {
    
    var giornoId: String
    var gruppoId: String
    var esercizioId: String
    var esercizio: Esercizio
    @State private var showingAlert = false
    @State private var nota: String
    @StateObject var imageLoader = ImageLoader()
    @State private var showTimerSheet = false
    @State private var showFullScreenImage = false
    @State private var isToastPresented = false

    init(giornoId: String, gruppoId: String, esercizioId: String, esercizio: Esercizio, showingAlert: Bool = false) {
        self.giornoId = giornoId
        self.gruppoId = gruppoId
        self.esercizioId = esercizioId
        self.esercizio = esercizio
        self.showingAlert = showingAlert
        self._nota = State(initialValue: esercizio.noteUtente ?? "")
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false)  {
            VStack(alignment: .leading) {
                ZStack {
                    VStack(alignment: .leading) {
                        if let image = imageLoader.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .cornerRadius(5)
                                .onTapGesture {
                                    showFullScreenImage.toggle()
                                }
                                .fullScreenCover(isPresented: $showFullScreenImage) {
                                    FullScreenImageView(image: image)
                                }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .frame(height: 250)
                                    .foregroundColor(.gray.opacity(0.2))
                                if imageLoader.error != nil {
                                    Text("Immagine non disponibile")
                                        .montserrat(size: 20)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
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
                                    Text("\(riposo) recupero")
                                        .montserrat(size: 20)
                                    Button(action: {
                                        showTimerSheet.toggle()
                                    }, label: {
                                        HStack {
                                            Image(systemName: "timer")
                                            Text("Avvia Timer di Recupero")
                                        }
                                        .frame(maxWidth: .infinity)
                                    })
                                    .montserrat(size: 18)
                                    .buttonStyle(BorderedProminentButtonStyle())
                                    .controlSize(.large)
                                }
                            }
                            
                            VStack(alignment: .leading, content: {
                                Text("Note PT:")
                                    .montserrat(size: 15)
                                    .fontWeight(.bold)
                                if let notePT = esercizio.notePT, !notePT.isEmpty {
                                    Text(notePT)
                                        .montserrat(size: 15)
                                } else {
                                    Text("Nessuna nota.")
                                        .montserrat(size: 15)
                                }
                            })
                        }
                        
                        Spacer()
                    }
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
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Aggiungi Nota")
                        }
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

        }
        .onAppear {
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(esercizio.name).png"
            imageLoader.loadImage(from: storagePath)
        }
        .padding()
        .navigationTitle(esercizio.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTimerSheet) {
            TimerSheet(riposo: esercizio.riposo ?? "")
        }
        .toast(isPresented: $isToastPresented, message: "Nota Salvata!")
    }
    
    func addNota() {
        guard let code = UserDefaults.standard.string(forKey: "code") else {
            print("Codice utente non trovato.")
            return
        }
        
        let ref = Database.database().reference()
            .child("users")
            .child(code)
            .child("scheda")
            .child("giorni")
            .child(giornoId)
            .child("gruppiMuscolari")
            .child(gruppoId)
            .child("esercizi")
            .child(esercizioId)
            .child("noteUtente")
        
        ref.setValue(nota) { error, _ in
            if let error = error {
                print("Errore nel salvataggio della nota utente: \(error.localizedDescription)")
            } else {
                isToastPresented = true
                print("Nota utente salvata con successo")
            }
        }
    }
}

struct FullScreenImageView: View {
    var image: UIImage
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    })
                }
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

struct TimerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var timeRemaining: Int
    @State private var totalTime: Int
    @State private var timerIsActive = false
    @State private var timerPaused = false
    @State private var timer: Timer?

    @State private var audioPlayer: AVAudioPlayer?

    init(riposo: String) {
        let parsedTime = TimerSheet.parseRiposo(riposo)
        _timeRemaining = State(initialValue: parsedTime)
        _totalTime = State(initialValue: parsedTime)
    }

    var body: some View {
        NavigationView {
            VStack {
                Spacer()

                Text("Tempo di recupero")
                    .montserrat(size: 30)
                    .bold()
                    .padding(.bottom, 40)

                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(Double(timeRemaining) / Double(totalTime)))
                        .stroke(Color.accentColor, lineWidth: 10)
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    Text(formatTime(timeRemaining))
                        .montserrat(size: 80)
                        .bold()
                }
                .padding()

                Spacer()

                HStack {
                    if timerIsActive {
                        Button(action: stopTimer) {
                            HStack {
                                Image(systemName: "stop.circle")
                                Text("Stop")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else if timerPaused {
                        Button(action: startTimer) {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Riprendi")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button(action: startTimer) {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Inizia")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Chiudi") {
                presentationMode.wrappedValue.dismiss()
            })
            .interactiveDismissDisabled(true)
        }
    }

    // Funzione per avviare il timer
    func startTimer() {
        if !timerIsActive {
            timerIsActive = true
            timerPaused = false
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer?.invalidate()
                    timerIsActive = false
                    playSound()
                    triggerVibration()
                }
            }
        }
    }

    // Funzione per stoppare il timer
    func stopTimer() {
        timer?.invalidate()
        timerIsActive = false
        timerPaused = true
    }

    // Funzione per convertire secondi in formato mm:ss
    func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Funzione per parsare il riposo (esempio formato "m'ss''")
    static func parseRiposo(_ riposo: String) -> Int {
        let components = riposo.split(separator: "'")
        if components.count == 2 {
            let minutes = Int(components[0]) ?? 0
            let seconds = Int(components[1].replacingOccurrences(of: "\"", with: "")) ?? 0
            return minutes * 60 + seconds
        }
        return 0
    }

    // Riproduci il suono quando il timer finisce
    func playSound() {
        AudioServicesPlaySystemSound(SystemSoundID(1022))
    }

    // Attiva la vibrazione quando il timer finisce
    func triggerVibration() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
