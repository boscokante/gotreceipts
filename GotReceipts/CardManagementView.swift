import SwiftUI

struct CardManagementView: View {
    @ObservedObject var cardService: CardService
    @Environment(\.dismiss) private var dismiss
    
    @State private var lastFour = ""
    @State private var entity = ""
    @State private var cardType = ""
    @State private var bank = ""
    @State private var errorMessage = ""
    @State private var isAddingCard = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Add Card Form
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add New Card")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    TextField("Last 4 digits (e.g., 1549)", text: $lastFour)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: lastFour) { _, newValue in
                            // Limit to 4 digits
                            if newValue.count > 4 {
                                lastFour = String(newValue.prefix(4))
                            }
                        }
                    
                    TextField("Entity (e.g., HiiiWAV)", text: $entity)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Card Type (e.g., CC)", text: $cardType)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Bank (e.g., BofA)", text: $bank)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: addCard) {
                        HStack {
                            if isAddingCard {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Add Card")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isAddingCard || lastFour.count != 4 || entity.isEmpty || cardType.isEmpty || bank.isEmpty)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Cards List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Cards")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    if cardService.cards.isEmpty {
                        Text("No cards added yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        List {
                            ForEach(cardService.cards) { card in
                                CardRowView(card: card, cardService: cardService)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Manage Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addCard() {
        guard lastFour.count == 4,
              !entity.isEmpty,
              !cardType.isEmpty,
              !bank.isEmpty else {
            errorMessage = "All fields are required"
            return
        }
        
        isAddingCard = true
        errorMessage = ""
        
        cardService.addCard(lastFour: lastFour, entity: entity, cardType: cardType, bank: bank) { error in
            DispatchQueue.main.async {
                isAddingCard = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    // Clear form on success
                    lastFour = ""
                    entity = ""
                    cardType = ""
                    bank = ""
                    errorMessage = ""
                }
            }
        }
    }
}

struct CardRowView: View {
    let card: Card
    @ObservedObject var cardService: CardService
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Text(card.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button(action: toggleCard) {
                    Text(card.active ? "Active" : "Inactive")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(card.active ? Color.green : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                Button(action: deleteCard) {
                    Text("Delete")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleCard() {
        cardService.toggleCardActive(cardId: card.id) { error in
            if let error = error {
                print("Error toggling card: \(error)")
            }
        }
    }
    
    private func deleteCard() {
        cardService.removeCard(cardId: card.id) { error in
            if let error = error {
                print("Error deleting card: \(error)")
            }
        }
    }
}

#Preview {
    CardManagementView(cardService: CardService())
}
