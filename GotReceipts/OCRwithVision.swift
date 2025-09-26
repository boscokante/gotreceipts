//
//  OCRwithVision.swift
//  GotReceipts
//
//  Created by Bosco "Bosko" Kante on 9/26/25.
//
import Vision

func recognizeText(in image: CGImage) async throws -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US"]
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    let texts = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return texts
}

