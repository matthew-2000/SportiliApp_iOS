//
//  SchedaViewModel.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

final class SchedaViewModel: ObservableObject {
    @Published var scheda: Scheda?
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var hasLoadedOnce: Bool

    private let schedaManager: SchedaManager
    private let autoFetchOnInit: Bool
    private var generation = UUID()
    private var currentCode: String?
    private var defaultsObserver: NSObjectProtocol?

    init(
        schedaManager: SchedaManager = SchedaManager(),
        autoFetchOnInit: Bool = true,
        scheda: Scheda? = nil
    ) {
        self.schedaManager = schedaManager
        self.autoFetchOnInit = autoFetchOnInit
        self.scheda = scheda
        self.isLoading = false
        self.errorMessage = nil
        self.hasLoadedOnce = scheda != nil

        if autoFetchOnInit {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self, self.currentCode != UserDefaults.standard.string(forKey: "code") else { return }
                self.fetchScheda()
            }
            fetchScheda()
        }
    }

    deinit {
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        schedaManager.stopObserving()
    }

    func fetchScheda() {
        generation = UUID()
        let token = generation
        schedaManager.stopObserving()
        guard let code = UserDefaults.standard.string(forKey: "code"), LoginSession.validUserCode(code) else {
            currentCode = nil
            isLoading = false
            hasLoadedOnce = true
            scheda = nil
            errorMessage = "Codice utente mancante. Effettua di nuovo l'accesso."
            return
        }

        if currentCode != code { scheda = nil; hasLoadedOnce = false }
        currentCode = code
        isLoading = true
        errorMessage = nil

        schedaManager.getSchedaFromFirebaseResult(code: code) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == token,
                      UserDefaults.standard.string(forKey: "code") == code else { return }
                self.isLoading = false
                self.hasLoadedOnce = true

                switch result {
                case .success(let scheda):
                    self.scheda = scheda
                    self.errorMessage = nil
                case .failure(let error):
                    self.scheda = nil
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
