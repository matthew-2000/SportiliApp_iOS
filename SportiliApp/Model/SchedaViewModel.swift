//
//  SchedaViewModel.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class SchedaViewModel: ObservableObject {
    @Published var scheda: Scheda?
    private var schedaManager: SchedaManager = SchedaManager()
    
    init() {
        fetchScheda()
    }

    func fetchScheda() {
        
        guard let code = UserDefaults.standard.string(forKey: "code") else {
            return
        }
        
        schedaManager.getSchedaFromFirebase(code: code, completion: { scheda in
            DispatchQueue.main.async {
                self.scheda = scheda
            }
        })

    }
    
}
