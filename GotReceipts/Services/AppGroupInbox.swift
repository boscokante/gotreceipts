import Foundation
import UIKit
import CoreLocation

enum AppGroupInbox {
    static let appGroupId: String = "group.gotreceipts"
    static let inboxFolderName: String = "ShareInbox"

    static func inboxURL() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let folder = container.appendingPathComponent(inboxFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func consumeImages(completion: @escaping (_ image: UIImage, _ photoLocation: CLLocation?, _ photoTimestamp: Date?) -> Void) {
        guard let folder = inboxURL() else {
            print("📁 AppGroupInbox: No container URL")
            return
        }
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            print("📁 AppGroupInbox: No files in folder")
            return
        }
        
        print("📁 AppGroupInbox: Found \(files.count) files")
        
        for file in files {
            let ext = file.pathExtension.lowercased()
            print("📁 AppGroupInbox: Processing file \(file.lastPathComponent) with extension \(ext)")
            guard ["jpg","jpeg","png"].contains(ext) else { continue }
            var photoLocation: CLLocation? = nil
            var photoTimestamp: Date? = nil
            // If there's a sidecar JSON with metadata, parse it
            let metaURL = file.deletingPathExtension().appendingPathExtension("json")
            if let metaData = try? Data(contentsOf: metaURL),
               let json = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
                if let lat = json["lat"] as? Double, let lng = json["lng"] as? Double {
                    let ts: Date?
                    if let iso = json["timestamp"] as? String { ts = ISO8601DateFormatter().date(from: iso) } else { ts = nil }
                    photoTimestamp = ts
                    photoLocation = CLLocation(latitude: lat, longitude: lng)
                }
            }
            if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                print("📁 AppGroupInbox: Successfully loaded image, calling completion")
                completion(image, photoLocation, photoTimestamp)
            }
            try? FileManager.default.removeItem(at: file)
            // Clean up sidecar if exists
            if FileManager.default.fileExists(atPath: metaURL.path) {
                try? FileManager.default.removeItem(at: metaURL)
            }
        }
    }
}


