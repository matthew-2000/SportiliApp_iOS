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
            fetchScheda()
        }
    }

    func fetchScheda() {
        guard let code = UserDefaults.standard.string(forKey: "code") else {
            isLoading = false
            hasLoadedOnce = true
            scheda = nil
            errorMessage = "Codice utente mancante. Effettua di nuovo l'accesso."
            return
        }

        isLoading = true
        errorMessage = nil

        schedaManager.getSchedaFromFirebaseResult(code: code) { result in
            DispatchQueue.main.async {
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
