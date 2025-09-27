// ... existing code ...
        collection.document(id).updateData(data, completion: completion)
    }
    
    // New function to delete a receipt document from Firestore.
    func deleteReceipt(id: String, completion: @escaping (Error?) -> Void) {
        guard let collection = receiptsCollectionRef() else {
            completion(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }
        
        collection.document(id).delete { error in
            if let error = error {
                print("❌ Error deleting receipt from Firestore: \(error.localizedDescription)")
            } else {
                print("✅ Receipt successfully deleted from Firestore.")
            }
            completion(error)
        }
    }
}