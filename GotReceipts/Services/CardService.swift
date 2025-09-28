import Foundation
import FirebaseFirestore
import FirebaseAuth

class CardService: ObservableObject {
    @Published var cards: [Card] = []
    private let db = Firestore.firestore()
    private let companyKey = "electrospit" // TODO: Make this dynamic based on user
    private var cardsListener: ListenerRegistration?
    
    init() {
        // Wait for auth to be ready before listening
        if Auth.auth().currentUser != nil {
            listenForCards()
        } else {
            Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard user != nil else { return }
                self?.listenForCards()
            }
        }
    }
    
    deinit {
        cardsListener?.remove()
    }
    
    private func listenForCards() {
        cardsListener = db.collection("userCards")
            .document(companyKey)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let document = documentSnapshot,
                      document.exists,
                      let data = document.data(),
                      let cardsData = data["cards"] as? [[String: Any]] else {
                    self?.cards = []
                    return
                }
                
                self?.cards = cardsData.compactMap { cardData in
                    guard let id = cardData["id"] as? String,
                          let lastFour = cardData["lastFour"] as? String,
                          let entity = cardData["entity"] as? String,
                          let cardType = cardData["cardType"] as? String,
                          let bank = cardData["bank"] as? String,
                          let active = cardData["active"] as? Bool,
                          let createdAtTimestamp = cardData["createdAt"] as? Timestamp else {
                        return nil
                    }
                    
                    return Card(
                        id: id,
                        lastFour: lastFour,
                        entity: entity,
                        cardType: cardType,
                        bank: bank,
                        active: active,
                        createdAt: createdAtTimestamp.dateValue()
                    )
                }
            }
    }
    
    func addCard(lastFour: String, entity: String, cardType: String, bank: String, completion: @escaping (Error?) -> Void) {
        let newCard = Card(
            id: UUID().uuidString,
            lastFour: lastFour,
            entity: entity,
            cardType: cardType,
            bank: bank,
            active: true,
            createdAt: Date()
        )
        
        let cardData: [String: Any] = [
            "id": newCard.id,
            "lastFour": newCard.lastFour,
            "entity": newCard.entity,
            "cardType": newCard.cardType,
            "bank": newCard.bank,
            "active": newCard.active,
            "createdAt": Timestamp(date: newCard.createdAt)
        ]
        
        let docRef = db.collection("userCards").document(companyKey)
        
        // First get existing cards
        docRef.getDocument { document, error in
            if let error = error {
                completion(error)
                return
            }
            
            var existingCards: [[String: Any]] = []
            if let document = document, document.exists {
                existingCards = document.data()?["cards"] as? [[String: Any]] ?? []
            }
            
            // Check if card already exists
            if existingCards.contains(where: { ($0["lastFour"] as? String) == lastFour }) {
                completion(NSError(domain: "CardService", code: 1, userInfo: [NSLocalizedDescriptionKey: "A card with this last four already exists"]))
                return
            }
            
            existingCards.append(cardData)
            
            // Update with new cards array
            docRef.setData(["cards": existingCards], merge: true) { error in
                completion(error)
            }
        }
    }
    
    func removeCard(cardId: String, completion: @escaping (Error?) -> Void) {
        let docRef = db.collection("userCards").document(companyKey)
        
        // First get existing cards
        docRef.getDocument { document, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let document = document, document.exists,
                  var existingCards = document.data()?["cards"] as? [[String: Any]] else {
                completion(NSError(domain: "CardService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Document not found"]))
                return
            }
            
            existingCards.removeAll { $0["id"] as? String == cardId }
            
            // Update with filtered cards array
            docRef.setData(["cards": existingCards], merge: true) { error in
                completion(error)
            }
        }
    }
    
    func toggleCardActive(cardId: String, completion: @escaping (Error?) -> Void) {
        let docRef = db.collection("userCards").document(companyKey)
        
        // First get existing cards
        docRef.getDocument { document, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let document = document, document.exists,
                  var existingCards = document.data()?["cards"] as? [[String: Any]] else {
                completion(NSError(domain: "CardService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Document not found"]))
                return
            }
            
            if let index = existingCards.firstIndex(where: { $0["id"] as? String == cardId }) {
                existingCards[index]["active"] = !(existingCards[index]["active"] as? Bool ?? true)
                
                // Update with modified cards array
                docRef.setData(["cards": existingCards], merge: true) { error in
                    completion(error)
                }
            } else {
                completion(NSError(domain: "CardService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Card not found"]))
            }
        }
    }
    
    // Find card by last four digits
    func findCard(by lastFour: String) -> Card? {
        return cards.first { $0.lastFour == lastFour && $0.active }
    }
    
    // Find cards by partial last four (for speech recognition)
    func findCards(containing partialLastFour: String) -> [Card] {
        return cards.filter { card in
            card.active && card.lastFour.contains(partialLastFour)
        }
    }
}
