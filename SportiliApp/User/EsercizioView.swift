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

struct UniformLog: Identifiable {
    let id: Int
    let index: Int
    let date: Date
    let weight: Double
}


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
    
    private var uniformLogs: [UniformLog] {
        let logs = sortedWeightLogs.suffix(10)
        return Array(logs.enumerated().map { (idx, log) in
            UniformLog(id: idx, index: idx, date: log.date, weight: log.weight)
        })
    }


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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                // ——— IMMAGINE COMPATTA ———
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { showFullScreenImage.toggle() }
                        .fullScreenCover(isPresented: $showFullScreenImage) {
                            FullScreenImageView(image: image)
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 160)
                        if imageLoader.error != nil {
                            Text("Immagine non disponibile")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                }

                // ——— SERIE & RIPOSO ———
                HStack {
                    Text(esercizio.serie)
                        .font(.title2.bold())
                        .foregroundColor(.accentColor)
                    Spacer()
                    if let riposo = esercizio.riposo, !riposo.isEmpty {
                        Text("\(riposo) recupero")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // ——— NOTE PT ———
                if let notePT = esercizio.notePT, !notePT.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note PT")
                            .font(.headline)
                        Text(notePT)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                Divider().padding(.vertical, 4)

                // ——— GRAFICO PESO ———
                VStack(alignment: .leading, spacing: 12) {
                    Text("Andamento Peso")
                        .font(.headline)

                    if uniformLogs.isEmpty {
                        Text("Nessun peso registrato.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        if let latest = latestWeightLog {
                            Text(summaryText(for: latest))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        WeightChartView(data: uniformLogs, dateFormatter: {
                            let f = DateFormatter()
                            f.dateFormat = "dd MMM"
                            f.locale = Locale(identifier: "it_IT")
                            return f
                        }())
                        .frame(height: 220)

                        // (facoltativo) ultimi 3 log in lista
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(lastTenWeightLogs.reversed().prefix(3))) { log in
                                HStack {
                                    Text(formattedDate(for: log))
                                    Spacer()
                                    Text("\(formattedWeight(log.weight)) kg")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }

                }

                // ——— BOTTONI AZIONE ———
                VStack(spacing: 10) {
                    Button {
                        showingWeightAlert.toggle()
                    } label: {
                        Label("Registra Peso", systemImage: "chart.xyaxis.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if let riposo = esercizio.riposo, !riposo.isEmpty {
                        Button {
                            showTimerSheet.toggle()
                        } label: {
                            Label("Avvia Timer di Recupero", systemImage: "timer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal)
        }
        .navigationTitle(esercizio.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTimerSheet) {
            TimerSheet(riposo: esercizio.riposo ?? "")
        }
        .toast(isPresented: $isToastPresented, message: "Peso salvato!")
        .alert("Registra peso", isPresented: $showingWeightAlert) {
            TextField("Peso (kg)", text: $nuovoPeso)
                .keyboardType(.decimalPad)
            Button("Salva", action: addWeightLog)
            Button("Annulla", role: .cancel) {
                nuovoPeso = ""
            }
        } message: {
            Text("Inserisci il peso sollevato per questo esercizio.")
        }
        .onAppear {
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(esercizio.name).png"
            imageLoader.loadImage(from: storagePath)
        }
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

struct WeightChartView: View {
    let data: [UniformLog]
    let dateFormatter: DateFormatter

    // gradient semplice e tipato (type erasure per evitare inference)
    private var lineGradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [Color.blue, Color.purple],
            startPoint: .leading,
            endPoint: .trailing
        ))
    }

    var body: some View {
        Chart {
            // Area (riempimento) – separata
//            ForEach(data) { item in
//                AreaMark(
//                    x: .value("Index", item.index),
//                    y: .value("Peso", item.weight)
//                )
//                .interpolationMethod(.catmullRom)
//                .foregroundStyle(LinearGradient(
//                    colors: [Color.blue.opacity(0.22), Color.purple.opacity(0.22)],
//                    startPoint: .top,
//                    endPoint: .bottom
//                ))
//            }

            // Linea – separata
            ForEach(data) { item in
                LineMark(
                    x: .value("Index", item.index),
                    y: .value("Peso", item.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(lineGradient)
            }

            // Punti – separati
            ForEach(data) { item in
                PointMark(
                    x: .value("Index", item.index),
                    y: .value("Peso", item.weight)
                )
                .symbolSize(60)
                .foregroundStyle(.accent)
                .annotation(position: .top) {
                    Text("\(formatWeight(item.weight)) kg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: data.map { $0.index }) { value in
                if let idx = value.as(Int.self),
                   let item = data.first(where: { $0.index == idx }) {
                    AxisValueLabel {
                        Text(dateFormatter.string(from: item.date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }

    // formatter leggero per i label peso sopra i punti (no NumberFormatter per semplificare)
    private func formatWeight(_ w: Double) -> String {
        if w == floor(w) { return String(format: "%.0f", w) }
        return String(format: "%.1f", w)
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
