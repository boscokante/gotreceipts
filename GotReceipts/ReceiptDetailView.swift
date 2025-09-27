import SwiftUI
import FirebaseStorage // Import FirebaseStorage to download images

struct ReceiptDetailView: View {
    let receipt: Receipt
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let fileStorageService = FileStorageService()

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading Image...")
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .padding()
                }
            } else {
                Text("Could not load image.")
            }
        }
        .navigationTitle("Receipt Image")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        guard let path = receipt.imagePath else {
            errorMessage = "Receipt has no image path."
            isLoading = false
            return
        }

        // Check if the path is a local file or a cloud URL.
        if path.hasPrefix("https://") {
            // It's a cloud URL, download from Firebase.
            let storageRef = Storage.storage().reference(forURL: path)
            storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
                if let error = error {
                    errorMessage = "Failed to download image: \(error.localizedDescription)"
                } else if let data = data, let downloadedImage = UIImage(data: data) {
                    self.image = downloadedImage
                } else {
                    errorMessage = "Image data was corrupt or invalid."
                }
                isLoading = false
            }
        } else {
            // It's a local file path, load from disk.
            self.image = fileStorageService.loadImage(from: path)
            if self.image == nil {
                errorMessage = "Could not load local image from disk."
            }
            isLoading = false
        }
    }
}