import SwiftUI
import VisionKit

// A new enum to represent the result of the scan
enum ScanResult {
    case success([UIImage])
    case failure(Error)
    case canceled
}

// The new scanner view uses a completion handler (callback)
// instead of multiple bindings. This is a cleaner pattern.
struct DocumentScannerView: UIViewControllerRepresentable {
    
    var completion: (ScanResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let documentViewController = VNDocumentCameraViewController()
        documentViewController.delegate = context.coordinator
        return documentViewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var completion: (ScanResult) -> Void

        init(completion: @escaping (ScanResult) -> Void) {
            self.completion = completion
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: pageIndex))
            }
            completion(.success(images))
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completion(.canceled)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completion(.failure(error))
        }
    }
}