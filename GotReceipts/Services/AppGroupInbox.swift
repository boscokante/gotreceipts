import Foundation
import UIKit

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

    static func consumeImages(completion: @escaping (UIImage) -> Void) {
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
            if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                print("📁 AppGroupInbox: Successfully loaded image, calling completion")
                completion(image)
            }
            try? FileManager.default.removeItem(at: file)
        }
    }
}


