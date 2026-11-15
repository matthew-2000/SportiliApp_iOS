import Foundation
import FirebaseDatabase

/// Inserts only the immutable recording node. Never replaces exerciseData or a session collection.
final class WatchFirebaseWriter {
    let database: Database
    init(database: Database = Database.database()) { self.database = database }
    func save(_ recording: WatchRecording, path: String,
              completion: @escaping (Result<WatchReceiptStatus, Error>) -> Void) {
        guard recording.isValid else {
            completion(.failure(ExerciseDataError.message("Registrazione Watch non valida.")))
            return
        }
        // Reuse the existing iPhone model serializers; Watch DTOs never add backend fields.
        let payload: [String: Any]
        if let weight = recording.single {
            payload = WeightLog(id: recording.id, timestamp: recording.timestamp, weight: weight).firebaseValue
        } else {
            payload = WorkoutWeightSession(id: recording.id, timestamp: recording.timestamp,
                sets: recording.sets.map { WorkoutWeightSet(reps: $0.reps, weight: $0.weight) }).firebaseValue
        }
        database.reference(withPath: path).runTransactionBlock({ mutable in
            switch watchInsertDecision(existing: mutable.value, recording: recording) {
            case .insert: mutable.value = payload; return TransactionResult.success(withValue: mutable)
            // Even an identical value must pass server CAS before acknowledging persistence.
            case .identical: return TransactionResult.success(withValue: mutable)
            case .conflict: return TransactionResult.abort()
            }
        }, andCompletionBlock: { error, committed, _ in
            DispatchQueue.main.async {
                if let error { completion(.failure(error)) }
                else { completion(.success(committed ? .saved : .conflict)) }
            }
        }, withLocalEvents: false)
    }
}
