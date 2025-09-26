//
//  DateDetection.swift
//  GotReceipts
//
//  Created by Bosco "Bosko" Kante on 9/26/25.
//
import Foundation

func detectDates(in text: String) -> [Date] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector.matches(in: text, options: [], range: range)
        .compactMap { $0.date }
}

