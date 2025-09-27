import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreService {
    
    private let db = Firestore.firestore()

    private func receiptsCollectionRef() -> CollectionReference? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(userId).collection("receipts")
    }

    // This function now returns the new document's ID.
    func saveReceipt(_ receipt: Receipt, completion: @escaping (String?, Error?) -> Void) {
        guard let collection = receiptsCollectionRef() else {
            completion(nil, NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }
        
        do {
            let newDocumentRef = try collection.addDocument(from: receipt) { error in
                completion(nil, error)
            }
            // On success, the error is nil, and we return the ID.
            completion(newDocumentRef.documentID, nil)
        } catch {
            print("❌ Error saving receipt to Firestore: \(error)")
            completion(nil, error)
        }
    }
    
    func listenForReceipts(completion: @escaping ([Receipt]) -> Void) -> ListenerRegistration? {
        guard let collection = receiptsCollectionRef() else { return nil }
        
        return collection
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error fetching snapshots: \(error!)")
                    return
                }
                
                let receipts = snapshot.documents.compactMap { document -> Receipt? in
                    var receipt = try? document.data(as: Receipt.self)
                    receipt?.id = document.documentID
                    return receipt
                }
                
                completion(receipts)
            }
    }
    
    func updateReceipt(id: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        guard let collection = receiptsCollectionRef() else {
            completion(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }
        
        collection.document(id).updateData(data, completion: completion)
    }
}