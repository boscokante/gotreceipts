//
//  ShareViewController.swift
//  GotReceiptsShareExtension
//
//  Created by Bosco "Bosko" Kante on 9/27/25.
//

import UIKit
import Social
import Photos
import UniformTypeIdentifiers
import ImageIO

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        print("📤 ShareExtension: didSelectPost called")
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("📤 ShareExtension: No input items")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let providers = items.compactMap { $0.attachments }.flatMap { $0 }
        print("📤 ShareExtension: Found \(providers.count) providers")
        
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.gotreceipts")?
            .appendingPathComponent("ShareInbox", isDirectory: true) else {
            print("📤 ShareExtension: No container URL")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        print("📤 ShareExtension: Container URL: \(groupURL)")
        try? FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true)

        let dispatchGroup = DispatchGroup()
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                print("📤 ShareExtension: Found image provider")
                dispatchGroup.enter()
                // Prefer fileRepresentation to preserve original metadata
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { tempURL, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        print("📤 ShareExtension: loadFileRepresentation error: \(error)")
                        return
                    }
                    guard let tempURL = tempURL else {
                        print("📤 ShareExtension: No file URL; falling back to loadItem")
                        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                            var writeURL: URL? = nil
                            if let url = item as? URL {
                                writeURL = url
                            } else if let img = item as? UIImage, let data = img.jpegData(compressionQuality: 0.95) {
                                let fallback = groupURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                                try? data.write(to: fallback)
                                writeURL = fallback
                            }
                            guard let writeURL else { return }
                            self.copyToGroupAndWriteSidecar(srcURL: writeURL, groupURL: groupURL)
                        }
                        return
                    }
                    self.copyToGroupAndWriteSidecar(srcURL: tempURL, groupURL: groupURL)
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            print("📤 ShareExtension: All images processed, completing request")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    // MARK: - Helpers
    private func copyToGroupAndWriteSidecar(srcURL: URL, groupURL: URL) {
        let ext = srcURL.pathExtension.isEmpty ? "jpg" : srcURL.pathExtension
        let dest = groupURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
            try FileManager.default.copyItem(at: srcURL, to: dest)
            print("📤 ShareExtension: Copied original with metadata to \(dest)")
        } catch {
            print("📤 ShareExtension: Copy failed (\(error)), trying data write")
            if let data = try? Data(contentsOf: srcURL) {
                try? data.write(to: dest)
            }
        }
        // Extract metadata
        let (lat, lng, date) = extractMetadata(from: dest)
        var meta: [String: Any] = [:]
        if let lat { meta["lat"] = lat }
        if let lng { meta["lng"] = lng }
        if let date { meta["timestamp"] = ISO8601DateFormatter().string(from: date) }
        if !meta.isEmpty {
            let metaURL = dest.deletingPathExtension().appendingPathExtension("json")
            if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: []) {
                try? metaData.write(to: metaURL)
            }
        }
    }

    private func extractMetadata(from url: URL) -> (Double?, Double?, Date?) {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return (nil, nil, nil)
        }
        let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        var lat: Double? = nil
        var lng: Double? = nil
        var date: Date? = nil
        if let v = gps?[kCGImagePropertyGPSLatitude] as? Double {
            let ref = (gps?[kCGImagePropertyGPSLatitudeRef] as? String) ?? "N"
            lat = (ref.uppercased() == "S") ? -v : v
        }
        if let v = gps?[kCGImagePropertyGPSLongitude] as? Double {
            let ref = (gps?[kCGImagePropertyGPSLongitudeRef] as? String) ?? "E"
            lng = (ref.uppercased() == "W") ? -v : v
        }
        if let dateStr = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
            let fmt = DateFormatter(); fmt.timeZone = TimeZone(secondsFromGMT: 0); fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            date = fmt.date(from: dateStr)
        }
        if date == nil, let ds = gps?[kCGImagePropertyGPSDateStamp] as? String, let tsRaw = gps?[kCGImagePropertyGPSTimeStamp] {
            let ts: String
            if let arr = tsRaw as? [NSNumber], arr.count >= 3 {
                // e.g., (HH, MM, SS.SSS)
                ts = String(format: "%02d:%02d:%02.0f", arr[0].intValue, arr[1].intValue, arr[2].doubleValue)
            } else {
                ts = (tsRaw as? String) ?? "00:00:00"
            }
            let fmt = DateFormatter(); fmt.timeZone = TimeZone(secondsFromGMT: 0); fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            date = fmt.date(from: "\(ds) \(ts)")
        }
        return (lat, lng, date)
    }
}
