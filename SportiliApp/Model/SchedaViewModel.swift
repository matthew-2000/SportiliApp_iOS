//
//  SchedaViewModel.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

final class SchedaViewModel: ObservableObject {
    @Published var scheda: Scheda?

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

        if autoFetchOnInit {
            fetchScheda()
        }
    }

    func fetchScheda() {
        guard let code = UserDefaults.standard.string(forKey: "code") else {
            return
        }

        schedaManager.getSchedaFromFirebase(code: code) { scheda in
            DispatchQueue.main.async {
                self.scheda = scheda
            }
        }
    }
}
