import Foundation
import UIKit

class FileStorageService {
    
    // Saves a UIImage to a local file and returns the path.
    func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("Could not get JPEG data from image.")
            return nil
        }
        
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("Image saved successfully at: \(fileURL.path)")
            return fileURL.path
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    // This new function loads a UIImage from a local file path.
    func loadImage(from path: String) -> UIImage? {
        let fileURL = URL(fileURLWithPath: path)
        do {
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch {
            print("Error loading image from path \(path): \(error)")
            return nil
        }
    }
    
    // Helper function to get the app's private documents directory.
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}