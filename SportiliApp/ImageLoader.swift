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

    private var requestID = UUID()

    func loadImage(from storagePath: String) {
        // A part change must not retain the previous image or accept its late callback.
        let request = UUID()
        requestID = request
        image = nil
        error = nil
        let storageRef = Storage.storage().reference(forURL: storagePath)
        storageRef.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            let loadedImage = data.flatMap(UIImage.init(data:))
            DispatchQueue.main.async {
                guard let self, self.requestID == request else { return }
                self.image = loadedImage
                self.error = error ?? (loadedImage == nil ? NSError(domain: "ExerciseImage", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Immagine non disponibile"]) : nil)
            }
        }
    }
}
