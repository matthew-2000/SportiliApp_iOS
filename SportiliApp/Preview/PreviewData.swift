import Foundation

enum PreviewData {
    static let weightLogs: [WeightLog] = [
        WeightLog(id: "log1", timestamp: Date().addingTimeInterval(-86400 * 7).timeIntervalSince1970, weight: 42.5),
        WeightLog(id: "log2", timestamp: Date().addingTimeInterval(-86400 * 4).timeIntervalSince1970, weight: 45),
        WeightLog(id: "log3", timestamp: Date().addingTimeInterval(-86400 * 1).timeIntervalSince1970, weight: 47.5)
    ]

    static let singleExercise = Esercizio(
        id: "esercizio1",
        name: "Panca piana",
        serie: "4 x 8",
        riposo: "90s",
        notePT: "Controlla la discesa",
        noteUtente: "Aumentare gradualmente",
        weightLogs: weightLogs
    )

    static let supersetExercise = Esercizio(
        id: "esercizio2",
        name: "Trazioni + Rematore",
        serie: "3 x 10",
        riposo: "75s",
        notePT: "Mantieni il core attivo"
    )

    static let gruppo = GruppoMuscolare(
        id: "gruppo1",
        nome: "Petto e Dorso",
        esercizi: [singleExercise, supersetExercise]
    )

    static let giorno = Giorno(
        id: "giorno1",
        name: "Giorno A",
        gruppiMuscolari: [gruppo]
    )

    static let scheda = Scheda(
        dataInizio: Date().addingTimeInterval(-86400 * 10),
        durata: 6,
        giorni: [giorno],
        cambioRichiesto: false
    )

    static let alerts: [UserAlert] = [
        makeAlert(
            id: "alert1",
            title: "Aggiornamento scheda",
            description: "La nuova scheda sarà disponibile da lunedì.",
            urgency: .media,
            daysUntilExpiry: 5
        ),
        makeAlert(
            id: "alert2",
            title: "Orari festivi",
            description: "La palestra chiuderà alle 18:00 il 31/12.",
            urgency: .bassa,
            daysUntilExpiry: 12
        ),
        makeAlert(
            id: "alert3",
            title: "Promemoria check-in",
            description: "Ricorda di registrare i progressi dopo l'allenamento.",
            urgency: .alta,
            daysUntilExpiry: 2
        )
    ]

    static func exerciseData(for exercise: Esercizio) -> [String: UserExerciseData] {
        let key = ExerciseDetailViewModel.makeExerciseKey(from: exercise.name)
        let logsDictionary = Dictionary(uniqueKeysWithValues: exercise.weightLogs.map { ($0.id, $0) })
        let data = UserExerciseData(noteUtente: exercise.noteUtente, weightLogs: logsDictionary)
        return [key: data]
    }

    private static func makeAlert(
        id: String,
        title: String,
        description: String,
        urgency: UserAlert.Urgency,
        daysUntilExpiry: Int
    ) -> UserAlert {
        let expiry = Date().addingTimeInterval(TimeInterval(daysUntilExpiry * 86400))
        let payload: [String: Any] = [
            "titolo": title,
            "descrizione": description,
            "urgenza": urgency.rawValue,
            "scadenza": expiry.timeIntervalSince1970 * 1000
        ]

        // Payload sempre valido per le preview.
        return UserAlert(id: id, data: payload) ?? UserAlert(
            id: id,
            titolo: title,
            descrizione: description,
            scadenza: expiry,
            urgenza: urgency
        )
    }
}

private extension UserAlert {
    init(id: String, titolo: String, descrizione: String, scadenza: Date?, urgenza: Urgency) {
        self.id = id
        self.titolo = titolo
        self.descrizione = descrizione
        self.scadenza = scadenza
        self.urgenza = urgenza
    }
}
