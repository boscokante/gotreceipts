import Foundation
import FirebaseStorage

class FirebaseStorageService {
    
    // Get a reference to the Firebase Cloud Storage service.
    private let storage = Storage.storage().reference()

    // Uploads an image from a local file URL to a unique path in Firebase Storage.
    // The completion handler returns the permanent cloud storage URL or an error.
    func uploadImage(from localURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // Create a unique path in Firebase Storage, e.g., "receipts/SOME_UNIQUE_ID.jpg"
        let fileName = localURL.lastPathComponent
        let storageRef = storage.child("receipts/\(fileName)")

        // Upload the local file to the cloud path.
        storageRef.putFile(from: localURL, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Error uploading to Firebase Storage: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // After a successful upload, get the permanent download URL.
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                if let downloadURL = url {
                    print("✅ Successfully uploaded image. URL: \(downloadURL)")
                    completion(.success(downloadURL))
                }
            }
        }
    }
}