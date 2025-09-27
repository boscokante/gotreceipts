import Foundation
import NaturalLanguage // Apple's framework for language analysis

struct ParsedReceiptData {
    var amount: Double?
    var date: Date?
    var merchant: String?
}

class ReceiptParser {
    
    // The main function that coordinates all parsing.
    func parse(ocrText: String) -> ParsedReceiptData {
        var parsedData = ParsedReceiptData()
        
        parsedData.amount = findTotalAmount(in: ocrText)
        parsedData.date = findDate(in: ocrText)
        parsedData.merchant = findMerchant(in: ocrText)
        
        return parsedData
    }
    
    // MARK: - Private Parsing Methods
    
    /// Finds the merchant name, prioritizing organization names in the first few lines.
    private func findMerchant(in text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        
        // The merchant name is almost always in the first 4 lines.
        let lines = text.split(separator: "\n")
        let textToSearch = lines.prefix(4).joined(separator: "\n")
        
        tagger.string = textToSearch
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let tags = tagger.tags(in: textToSearch.startIndex..<textToSearch.endIndex, unit: .word, scheme: .nameType, options: options)
        
        let organizationNames = tags.compactMap { tag, range -> String? in
            guard tag == .organizationName else { return nil }
            return String(textToSearch[range])
        }
        
        // Return the first organization name found. It's the most likely candidate.
        if let merchant = organizationNames.first {
            print("Found merchant using NLTagger: \(merchant)")
            return merchant
        }
        
        // Fallback: If no organization is found, return the first non-empty line.
        return lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }).map(String.init)
    }

    /// Finds the total amount using a robust two-pass strategy.
    private func findTotalAmount(in text: String) -> Double? {
        // Pass 1: Look for explicit keywords (total, amount, etc.)
        let keywordPattern = #"(?i)(?:total|amount|balance|invoice|charge|payment)\s*[:]?\s*[$€£]?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2}))"#
        
        do {
            let regex = try NSRegularExpression(pattern: keywordPattern)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            let amounts = results.compactMap { result -> Double? in
                guard result.numberOfRanges > 1 else { return nil }
                let amountString = nsString.substring(with: result.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                return Double(amountString)
            }
            
            if let maxAmount = amounts.max(), maxAmount > 0 {
                print("Found total amount using keywords: \(maxAmount)")
                return maxAmount
            }
        } catch {
            print("Keyword regex error: \(error.localizedDescription)")
        }
        
        // Pass 2: If no keyword amount was found, fall back to the largest number on the receipt.
        print("No keyword amount found. Falling back to largest number heuristic.")
        let numberPattern = #"(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2}))"#
        do {
            let regex = try NSRegularExpression(pattern: numberPattern)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            let allAmounts = results.compactMap { result -> Double? in
                let amountString = nsString.substring(with: result.range(at: 0)).replacingOccurrences(of: ",", with: ".")
                return Double(amountString)
            }
            
            if let maxAmount = allAmounts.max() {
                print("Found total amount using fallback heuristic: \(maxAmount)")
                return maxAmount
            }
        } catch {
            print("Fallback regex error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Finds the most plausible date in a block of text.
    private func findDate(in text: String) -> Date? {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            let validDates = matches.compactMap { $0.date }.filter { $0 <= Date() }
            return validDates.max()
        } catch {
            print("Error creating NSDataDetector: \(error)")
            return nil
        }
    }
}