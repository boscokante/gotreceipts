//
//  GotReceiptsApp.swift
//  GotReceipts
//
//  Created by Bosco "Bosko" Kante on 9/26/25.
//

import SwiftUI
import FirebaseCore

@main
struct GotReceiptsApp: App {
    @StateObject private var receiptStore = ReceiptStore()
    
    // Create an instance of our new authentication service.
    private let authService = FirebaseAuthenticationService()
    
    init() {
        FirebaseApp.configure()
        // Sign the user in as soon as the app is configured.
        authService.signInAnonymously()
    }
    
    var body: some Scene {
        WindowGroup {
            // ContentView is now correctly set as the root view.
            ContentView()
                .environmentObject(receiptStore)
        }
    }
}