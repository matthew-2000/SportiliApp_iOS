//
//  ImageLoader.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 25/06/24.
//

import Foundation
import FirebaseStorage
import SwiftUI

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var error: Error?

    func loadImage(from storagePath: String) {
        let storage = Storage.storage()
        let storageRef = storage.reference(forURL: storagePath)
        
        storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
            if let error = error {
                // Aggiorna la variabile error con l'errore rilevato
                self.error = error
                print("Errore nel caricamento dell'immagine:", error)
                // Se c'è un errore, prova a caricare l'immagine in formato PNG
            } else {
                if let imageData = data {
                    if let uiImage = UIImage(data: imageData) {
                        DispatchQueue.main.async {
                            self.image = uiImage
                        }
                    }
                }
            }
        }
    }
}
