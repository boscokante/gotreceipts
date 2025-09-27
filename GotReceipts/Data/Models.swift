import Foundation

struct Receipt: Identifiable, Codable {
    var id: String?
    let createdAt: Date
    let deviceId: String
    let userType: String
    let companyKey: String
    var status: String
    
    var imagePath: String?
    var ocrText: String?
    var geo: GeoLocation?
    let photoTimestamp: Date?
    
    var speech: String?
    var parsed: ParsedData?
    let qbo: QBOData?
    
    // We add coding keys to prevent encoding the id, as Firestore manages it.
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt, deviceId, userType, companyKey, status, imagePath, ocrText, geo, photoTimestamp, speech, parsed, qbo
    }
}

struct GeoLocation: Codable {
    let lat: Double
    let lng: Double
    let accuracyM: Int
}

struct ParsedData: Codable {
    var merchant: String?
    var amount: Double?
    let currency: String?
    var date: Date?
    let paymentMethod: String?
    let categoryHint: String?
    var purpose: String?
    let attendees: [String]?
    let projectOrCompany: String?
    let locationName: String?
}

struct QBOData: Codable {
    let realmId: String?
    let vendorRef: VendorRef?
    let expenseCategory: ExpenseCategory?
    let attachableId: String?
    let txnId: String?
}

struct VendorRef: Codable {
    let id: String
    let name: String
}

struct ExpenseCategory: Codable {
    let accountRefId: String
}