//
//  ContentView.swift
//  GotReceipts
//
//  Created by Bosco "Bosko" Kante on 9/26/25.
//

import SwiftUI
import UIKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    
    @State private var isShowingScanner = false
    @State private var isShowingSpeechInput = false
    @State private var activeReceiptID: String?
    
    private let locationService = LocationService()
    private let ocrService = OCRService()
    private let fileStorageService = FileStorageService()
    private let firebaseStorageService = FirebaseStorageService()
    private let receiptParser = ReceiptParser()

    var body: some View {
        NavigationStack {
            Group {
                if receiptStore.receipts.isEmpty {
                    emptyStateView
                } else {
                    receiptsListView
                }
            }
            .navigationTitle("GotReceipts")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { isShowingScanner = true }) {
                        Label("Scan Receipt", systemImage: "camera")
                            .font(.headline)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            DocumentScannerView { result in
                isShowingScanner = false
                if case .success(let images) = result, let image = images.first {
                    processScannedImage(image)
                }
            }
        }
        .sheet(isPresented: $isShowingSpeechInput) {
            if let receiptID = activeReceiptID {
                SpeechInputView(receiptID: receiptID)
            }
        }
        .onAppear {
            if receiptStore.receipts.isEmpty {
                isShowingScanner = true
            }
        }
    }

    private func processScannedImage(_ image: UIImage) {
        guard let localImagePath = fileStorageService.saveImage(image) else { return }

        // Step 1: Save the initial record to Firestore to get a permanent ID.
        receiptStore.addReceipt(ocrText: "Processing...", localImagePath: localImagePath) { permanentID in
            guard let realID = permanentID else {
                print("Failed to get permanent ID from Firestore.")
                return
            }
            
            // Step 2: Now that we have a reliable ID, show the speech view.
            self.activeReceiptID = realID
            self.isShowingSpeechInput = true

            // Step 3: Start all background tasks with the permanent ID.
            self.startBackgroundTasks(for: realID, with: image, localPath: localImagePath)
        }
    }
    
    private func startBackgroundTasks(for realID: String, with image: UIImage, localPath: String) {
        // Location Task
        locationService.requestLocation { location in
            guard let location = location else {
                print("Could not get location.")
                return
            }
            
            // Now that we have the location, reverse geocode it.
            self.locationService.reverseGeocode(location: location) { locationName in
                // Update the receipt with both the GPS data and the readable name.
                self.receiptStore.updateReceipt(id: realID, withLocation: location, locationName: locationName)
            }
        }
        
        // OCR Task
        performOCR(on: image, for: realID)
        
        // Firebase Storage Upload Task
        let localImageURL = URL(fileURLWithPath: localPath)
        firebaseStorageService.uploadImage(from: localImageURL) { result in
            if case .success(let cloudURL) = result {
                receiptStore.updateReceipt(id: realID, withCloudURL: cloudURL.absoluteString)
            }
        }
    }
    
    private func performOCR(on image: UIImage, for receiptID: String) {
        guard let cgImage = image.cgImage else { return }
        ocrService.performOCR(on: cgImage) { results in
            let recognizedText = results?.map { $0.text }.joined(separator: "\n") ?? "OCR failed."
            let parsedData = self.receiptParser.parse(ocrText: recognizedText)
            receiptStore.updateReceipt(id: receiptID, withOcrText: recognizedText, parsedData: parsedData)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("No Receipts Yet")
                .font(.title.bold())
            Text("Tap the button below to scan your first receipt.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Spacer()
        }
    }
    
    private var receiptsListView: some View {
        List(receiptStore.receipts) { receipt in
            NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                ReceiptRowView(receipt: receipt)
            }
        }
    }
}

// ReceiptRowView remains the same.
struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(receipt.parsed?.merchant ?? "Scanned Receipt")
                    .font(.headline)
                Spacer()
                
                if let imagePath = receipt.imagePath {
                    if imagePath.hasPrefix("https://") {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "paperclip")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let amount = receipt.parsed?.amount {
                    Text(amount, format: .currency(code: "USD"))
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            
            if let date = receipt.parsed?.date {
                Text(date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // New: Display the location name if it exists.
            if let locationName = receipt.parsed?.locationName, !locationName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(locationName)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            if let speech = receipt.speech, !speech.isEmpty {
                Text("“\(speech)”")
                    .font(.subheadline)
                    .italic()
            }
            
            if let ocrText = receipt.ocrText, ocrText != "Processing..." {
                Text(ocrText)
                    .lineLimit(2)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}