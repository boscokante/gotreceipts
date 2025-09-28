import Foundation
import SwiftUI
import FirebaseFirestore
import CoreLocation

@MainActor
class ReceiptStore: ObservableObject {
    @Published var receipts: [Receipt] = []
    
    private let firestoreService = FirestoreService()
    private var receiptsListener: ListenerRegistration?

    init() {
        listenForReceipts()
    }
    
    deinit {
        receiptsListener?.remove()
    }

    private func listenForReceipts() {
        receiptsListener = firestoreService.listenForReceipts { [weak self] fetchedReceipts in
            self?.receipts = fetchedReceipts
        }
    }
    
    // The `addReceipt` function now returns the permanent ID from Firestore.
    func addReceipt(ocrText: String, localImagePath: String, completion: @escaping (String?) -> Void) {
        let newReceipt = Receipt(
            id: nil, // Firestore will generate this
            createdAt: Date(),
            deviceId: "ios:device",
            userType: "initiator",
            companyKey: "electrospit",
            status: "new",
            imagePath: localImagePath, // Starts as a local path
            ocrText: ocrText,
            geo: nil,
            photoTimestamp: Date(),
            speech: nil,
            parsed: ParsedData(merchant: "Processing...", amount: nil, currency: "USD", date: nil, paymentMethod: nil, categoryHint: nil, purpose: nil, attendees: [], projectOrCompany: nil, locationName: nil),
            qbo: nil,
            lastFour: nil
        )
        
        // Save the initial receipt and get the permanent ID.
        firestoreService.saveReceipt(newReceipt) { documentID, error in
            if let error = error {
                print("Error saving receipt: \(error.localizedDescription)")
                completion(nil)
            } else {
                print("Receipt saved with permanent ID: \(documentID ?? "unknown")")
                completion(documentID)
            }
        }
    }
    
    // All update functions remain the same.
    func updateReceipt(id: String, withCloudURL cloudURL: String) {
        let data: [String: Any] = ["imagePath": cloudURL, "status": "uploaded"]
        firestoreService.updateReceipt(id: id, data: data, completion: { _ in })
    }
    
    func updateReceipt(id: String, withOcrText text: String, parsedData: ParsedReceiptData) {
        let data: [String: Any] = [
            "ocrText": text,
            "parsed.amount": parsedData.amount ?? NSNull(),
            "parsed.date": parsedData.date ?? NSNull(),
            "parsed.merchant": parsedData.merchant ?? "Unknown Merchant"
        ]
        firestoreService.updateReceipt(id: id, data: data, completion: { _ in })
    }
    
    func updateReceipt(id: String, withSpeech text: String) {
        let data: [String: Any] = ["speech": text]
        firestoreService.updateReceipt(id: id, data: data, completion: { _ in })
    }
    
    // This function now accepts the optional locationName.
    func updateReceipt(id: String, withLocation location: CLLocation, locationName: String?) {
        let geo = GeoLocation(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            accuracyM: Int(location.horizontalAccuracy)
        )
        
        let geoData: [String: Any] = ["lat": geo.lat, "lng": geo.lng, "accuracyM": geo.accuracyM]
        
        // Add both the geo data and the parsed location name to the update.
        let data: [String: Any] = [
            "geo": geoData,
            "parsed.locationName": locationName ?? NSNull()
        ]
        
        firestoreService.updateReceipt(id: id, data: data, completion: { _ in
            print("🧾 Updated receipt \(id) with location and location name.")
        })
    }
    
    func updateReceipt(id: String, withLastFour lastFour: String) {
        let data: [String: Any] = ["lastFour": lastFour]
        firestoreService.updateReceipt(id: id, data: data, completion: { _ in
            print("💳 Updated receipt \(id) with last four: \(lastFour)")
        })
    }
}