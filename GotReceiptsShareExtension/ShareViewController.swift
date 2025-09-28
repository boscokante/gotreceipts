//
//  ShareViewController.swift
//  GotReceiptsShareExtension
//
//  Created by Bosco "Bosko" Kante on 9/27/25.
//

import UIKit
import Social
import Photos

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
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                print("📤 ShareExtension: Found image provider")
                dispatchGroup.enter()
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        print("📤 ShareExtension: Error loading item: \(error)")
                        return
                    }
                    
                    var image: UIImage?
                    var meta: [String: Any] = [:]
                    if let url = item as? URL, let data = try? Data(contentsOf: url) {
                        image = UIImage(data: data)
                        print("📤 ShareExtension: Loaded image from URL")
                        // Try to fetch asset to read location/time
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            let assetResults = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil)
                            if let asset = assetResults.firstObject {
                                if let loc = asset.location {
                                    meta["lat"] = loc.coordinate.latitude
                                    meta["lng"] = loc.coordinate.longitude
                                }
                                meta["timestamp"] = ISO8601DateFormatter().string(from: asset.creationDate ?? Date())
                            }
                        }
                    } else if let img = item as? UIImage {
                        image = img
                        print("📤 ShareExtension: Loaded image directly")
                    }
                    
                    guard let img = image, let data = img.jpegData(compressionQuality: 0.9) else { 
                        print("📤 ShareExtension: Failed to process image")
                        return 
                    }
                    
                    let filename = UUID().uuidString + ".jpg"
                    let dest = groupURL.appendingPathComponent(filename)
                    do {
                        try data.write(to: dest)
                        print("📤 ShareExtension: Successfully saved image to \(dest)")
                        // Write sidecar JSON with metadata if available
                        if !meta.isEmpty {
                            let metaURL = dest.deletingPathExtension().appendingPathExtension("json")
                            if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: []) {
                                try? metaData.write(to: metaURL)
                            }
                        }
                    } catch {
                        print("📤 ShareExtension: Failed to save image: \(error)")
                    }
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

}
