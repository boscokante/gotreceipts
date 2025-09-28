import SwiftUI

struct SpeechInputView: View {
    
    // The service that handles the speech recognition.
    @StateObject private var speechRecognizer = SpeechRecognizerService()
    @StateObject private var cardService = CardService()
    
    // The ID of the receipt we are adding speech to.
    let receiptID: String
    
    // The store to update the receipt.
    @EnvironmentObject var receiptStore: ReceiptStore
    
    // The presentation mode to dismiss the view.
    @Environment(\.presentationMode) var presentationMode
    
    @State private var speechParser: SpeechParser?
    @State private var matchedCard: Card?
    @State private var showCardConfirmation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Text("Describe the Receipt")
                    .font(.title.bold())
                
                Text("Tap the microphone and speak. Example:\n*\"Dinner with Maya about the Q1 marketing plan for ElectroSpit ending in 1549.\"*")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // The text field showing the live transcript.
                TextEditor(text: $speechRecognizer.transcript)
                    .frame(height: 150)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .padding()
                
                // The microphone button.
                Button(action: {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                    } else {
                        speechRecognizer.startRecording()
                    }
                }) {
                    Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                }
                
                if !speechRecognizer.isAvailable {
                    Text("Speech recognition is unavailable. Please check your permissions in Settings.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Show matched card if found
                if let matchedCard = matchedCard {
                    VStack(spacing: 8) {
                        Text("Card Detected:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(matchedCard.description)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        speechRecognizer.stopRecording()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        speechRecognizer.stopRecording()
                        saveSpeechAndCard()
                    }
                    .disabled(speechRecognizer.transcript.isEmpty)
                }
            }
        }
        .onAppear {
            speechParser = SpeechParser(cardService: cardService)
        }
        .onChange(of: speechRecognizer.transcript) { _, newTranscript in
            parseSpeechForCard(newTranscript)
        }
        .alert("Card Detected", isPresented: $showCardConfirmation) {
            Button("Use This Card") {
                if let matchedCard = matchedCard {
                    receiptStore.updateReceipt(id: receiptID, withLastFour: matchedCard.lastFour)
                }
            }
            Button("Not Found", role: .cancel) { }
        } message: {
            if let matchedCard = matchedCard {
                Text("Did you use \(matchedCard.description)?")
            }
        }
    }
    
    private func parseSpeechForCard(_ speech: String) {
        guard let parser = speechParser else { return }
        let result = parser.parseSpeech(speech)
        
        if let foundCard = result.matchedCard {
            matchedCard = foundCard
        } else if let lastFour = result.lastFour {
            // Show confirmation for unmatched card
            matchedCard = Card(
                id: "temp",
                lastFour: lastFour,
                entity: "Unknown",
                cardType: "Unknown",
                bank: "Unknown",
                active: true,
                createdAt: Date()
            )
        } else {
            matchedCard = nil
        }
    }
    
    private func saveSpeechAndCard() {
        guard let parser = speechParser else { return }
        let result = parser.parseSpeech(speechRecognizer.transcript)
        
        // Update with cleaned memo (without card reference)
        receiptStore.updateReceipt(id: receiptID, withSpeech: result.memo)
        
        // Update with card info if found
        if let lastFour = result.lastFour {
            receiptStore.updateReceipt(id: receiptID, withLastFour: lastFour)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}