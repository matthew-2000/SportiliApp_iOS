import Foundation
import FirebaseDatabase

final class AlertsViewModel: ObservableObject {
    @Published private(set) var alerts: [UserAlert]
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?

    private let reference: DatabaseReference
    private let autoObserve: Bool
    private var handle: DatabaseHandle?

    init(
        database: DatabaseReference = Database.database().reference(),
        autoObserve: Bool = true,
        initialAlerts: [UserAlert] = [],
        initialLoading: Bool = false,
        initialErrorMessage: String? = nil
    ) {
        self.reference = database.child("alerts")
        self.autoObserve = autoObserve
        self.alerts = initialAlerts
        self.isLoading = initialLoading
        self.errorMessage = initialErrorMessage

        if autoObserve {
            observeAlerts()
        }
    }

    deinit {
        if let handle {
            reference.removeObserver(withHandle: handle)
        }
    }

    func retry() {
        guard autoObserve else { return }
        observeAlerts()
    }

    private func observeAlerts() {
        isLoading = true
        errorMessage = nil

        if let handle {
            reference.removeObserver(withHandle: handle)
        }

        handle = reference.observe(.value, with: { [weak self] snapshot in
            guard let self else { return }

            var loadedAlerts: [UserAlert] = []

            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let value = child.value as? [String: Any],
                      let alert = UserAlert(id: child.key, data: value),
                      !alert.isExpired else {
                    continue
                }
                loadedAlerts.append(alert)
            }

            DispatchQueue.main.async {
                self.alerts = loadedAlerts.sortedByPriority()
                self.isLoading = false
                self.errorMessage = nil
            }
        }, withCancel: { [weak self] error in
            DispatchQueue.main.async {
                self?.alerts = []
                self?.isLoading = false
                self?.errorMessage = error.localizedDescription
            }
        })
    }
}
