import Vision
import CoreGraphics

struct OCRResult {
    let text: String
    let boundingBox: CGRect
}

class OCRService {
    
    func performOCR(on image: CGImage, completion: @escaping ([OCRResult]?) -> Void) {        
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil)
                return
            }
            
            let results = observations.compactMap { observation -> OCRResult? in
                guard let topCandidate = observation.topCandidates(1).first else {
                    return nil
                }
                
                let boundingBox = observation.boundingBox
                return OCRResult(text: topCandidate.string, boundingBox: boundingBox)
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        request.recognitionLevel = .accurate
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}