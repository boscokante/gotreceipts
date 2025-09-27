import Foundation
import FirebaseAuth

class FirebaseAuthenticationService {
    
    // Signs the user in anonymously when the app starts.
    // This is required for our security rules to allow uploads.
    func signInAnonymously() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    print("‼️‼️‼️ FIREBASE AUTH ERROR: Failed to sign in anonymously: \(error.localizedDescription)")
                    return
                }
                if let user = authResult?.user {
                    print("✅✅✅ FIREBASE AUTH SUCCESS: Signed in anonymously with user ID: \(user.uid)")
                }
            }
        } else {
            print("✅✅✅ FIREBASE AUTH SUCCESS: User is already signed in as \(Auth.auth().currentUser?.uid ?? "unknown").")
        }
    }
}