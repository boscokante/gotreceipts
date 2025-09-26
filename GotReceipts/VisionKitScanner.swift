//
//  VisionKitScanner.swift
//  GotReceipts
//
//  Created by Bosco "Bosko" Kante on 9/26/25.
//
import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onImages: ([UIImage]) -> Void
        init(onImages: @escaping ([UIImage]) -> Void) { self.onImages = onImages }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images = [UIImage]()
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            controller.dismiss(animated: true) { self.onImages(images) }
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
    let onImages: ([UIImage]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImages: onImages) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
}

