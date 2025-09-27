import SwiftUI

struct SpeechInputView: View {
    
    // The service that handles the speech recognition.
    @StateObject private var speechRecognizer = SpeechRecognizerService()
    
    // The ID of the receipt we are adding speech to.
    let receiptID: String
    
    // The store to update the receipt.
    @EnvironmentObject var receiptStore: ReceiptStore
    
    // The presentation mode to dismiss the view.
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Text("Describe the Receipt")
                    .font(.title.bold())
                
                Text("Tap the microphone and speak. Example:\n*\"Dinner with Maya about the Q1 marketing plan for ElectroSpit.\"*")
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
                        // Update the store with the final transcript.
                        receiptStore.updateReceipt(id: receiptID, withSpeech: speechRecognizer.transcript)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(speechRecognizer.transcript.isEmpty)
                }
            }
        }
    }
}