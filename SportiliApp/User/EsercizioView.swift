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
import Charts

struct EsercizioView: View {
    
    var giornoId: String
    var gruppoId: String
    var esercizioId: String
    var esercizio: Esercizio
    @State private var showingWeightAlert = false
    @State private var nuovoPeso: String
    @State private var weightLogs: [WeightLog]
    @StateObject var imageLoader = ImageLoader()
    @State private var showTimerSheet = false
    @State private var showFullScreenImage = false
    @State private var isToastPresented = false

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    private static let summaryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    init(giornoId: String, gruppoId: String, esercizioId: String, esercizio: Esercizio, showingAlert: Bool = false) {
        self.giornoId = giornoId
        self.gruppoId = gruppoId
        self.esercizioId = esercizioId
        self.esercizio = esercizio
        self._showingWeightAlert = State(initialValue: showingAlert)
        self._nuovoPeso = State(initialValue: "")
        self._weightLogs = State(initialValue: esercizio.weightLogs)
    }

    private var sortedWeightLogs: [WeightLog] {
        weightLogs.sorted { $0.timestamp < $1.timestamp }
    }

    private var lastTenWeightLogs: [WeightLog] {
        let logs = sortedWeightLogs
        return logs.count > 10 ? Array(logs.suffix(10)) : logs
    }

    private var latestWeightLog: WeightLog? {
        sortedWeightLogs.last
    }

    private func formattedDate(for log: WeightLog) -> String {
        Self.logDateFormatter.string(from: log.date)
    }

    private func formattedWeight(_ value: Double) -> String {
        Self.weightFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func summaryText(for log: WeightLog) -> String {
        let formattedDate = Self.summaryDateFormatter.string(from: log.date)
        return "Ultimo peso: \(formattedWeight(log.weight)) kg - \(formattedDate)"
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
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Progressi Peso:")
                        .montserrat(size: 15)
                        .fontWeight(.bold)

                    if lastTenWeightLogs.isEmpty {
                        if let legacyNote = esercizio.noteUtente, !legacyNote.isEmpty {
                            Text(legacyNote)
                                .montserrat(size: 15)
                        } else {
                            Text("Nessun peso registrato.")
                                .montserrat(size: 15)
                        }
                    } else {
                        if let latest = latestWeightLog {
                            Text(summaryText(for: latest))
                                .montserrat(size: 15)
                        }

                        Chart(lastTenWeightLogs) { log in
                            LineMark(
                                x: .value("Data", log.date),
                                y: .value("Peso", log.weight)
                            )
                            PointMark(
                                x: .value("Data", log.date),
                                y: .value("Peso", log.weight)
                            )
                        }
                        .frame(height: 200)
                        .chartYScale(domain: .automatic(includesZero: false))

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(lastTenWeightLogs.reversed())) { log in
                                HStack {
                                    Text(formattedDate(for: log))
                                    Spacer()
                                    Text("\(formattedWeight(log.weight)) kg")
                                }
                                .montserrat(size: 14)
                            }
                        }
                    }

                    Button(action: {
                        showingWeightAlert.toggle()
                    }, label: {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                            Text("Registra Peso")
                        }
                        .frame(maxWidth: .infinity)
                    })
                    .montserrat(size: 18)
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.large)
                }
                .alert("Inserisci peso:", isPresented: $showingWeightAlert) {
                    TextField("Peso (kg)", text: $nuovoPeso)
                        .keyboardType(.decimalPad)
                        .montserrat(size: 15)
                    Button(action: addWeightLog, label: {
                        Text("Salva")
                    })
                    .montserrat(size: 15)
                    Button("Annulla", role: .cancel) {
                        nuovoPeso = ""
                    }
                } message: {
                    Text("Inserisci il peso sollevato per questo esercizio.")
                        .montserrat(size: 15)
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
        .toast(isPresented: $isToastPresented, message: "Peso salvato!")
    }

    func addWeightLog() {
        let trimmed = nuovoPeso.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("Peso non inserito")
            return
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let weightValue = Double(normalized), weightValue > 0 else {
            print("Peso non valido")
            return
        }

        guard let code = UserDefaults.standard.string(forKey: "code") else {
            print("Codice utente non trovato.")
            return
        }

        let esercizioRef = Database.database().reference()
            .child("users")
            .child(code)
            .child("scheda")
            .child("giorni")
            .child(giornoId)
            .child("gruppiMuscolari")
            .child(gruppoId)
            .child("esercizi")
            .child(esercizioId)

        let weightLogsRef = esercizioRef.child("weightLogs").childByAutoId()
        let timestamp = Date().timeIntervalSince1970 * 1000
        let logData: [String: Any] = [
            "timestamp": timestamp,
            "weight": weightValue
        ]

        weightLogsRef.setValue(logData) { error, _ in
            if let error = error {
                print("Errore nel salvataggio del peso: \(error.localizedDescription)")
                return
            }

            let newLog = WeightLog(id: weightLogsRef.key ?? UUID().uuidString, timestamp: timestamp, weight: weightValue)

            DispatchQueue.main.async {
                weightLogs.append(newLog)
                esercizio.weightLogs = weightLogs

                let summary = summaryText(for: newLog)
                esercizioRef.child("noteUtente").setValue(summary)
                esercizio.noteUtente = summary

                nuovoPeso = ""
                showingWeightAlert = false
                isToastPresented = true
                print("Peso salvato con successo")
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
