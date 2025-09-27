import Foundation
import FirebaseStorage

class FirebaseStorageService {
    
    private let storage = Storage.storage()

    // Uploads an image from a local file URL to a unique path in Firebase Storage.
    func uploadImage(from localURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let fileName = localURL.lastPathComponent
        let storageRef = storage.reference().child("receipts/\(fileName)")

        storageRef.putFile(from: localURL, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            storageRef.downloadURL { url, error in
                if let url = url {
                    completion(.success(url))
                } else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // New function to delete an image from Firebase Storage.
    func deleteImage(at cloudURL: String, completion: @escaping (Error?) -> Void) {
        let storageRef = storage.reference(forURL: cloudURL)
        
        storageRef.delete { error in
            if let error = error {
                print("❌ Error deleting image from Storage: \(error.localizedDescription)")
            } else {
                print("✅ Image successfully deleted from Storage.")
            }
            completion(error)
        }
    }
}