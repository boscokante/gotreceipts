import Foundation
import NaturalLanguage // Apple's framework for language analysis

// Simple regex helpers compatible with current Swift toolchain
private extension String {
    func matchesRegex(_ pattern: String, caseInsensitive: Bool = false) -> Bool {
        let opts: String.CompareOptions = caseInsensitive ? [.regularExpression, .caseInsensitive] : [.regularExpression]
        return self.range(of: pattern, options: opts) != nil
    }
}

struct ParsedReceiptData {
    var amount: Double?
    var date: Date?
    var merchant: String?
    var purpose: String?
    var paymentMethod: String?
}

class ReceiptParser {
    
    // The main function that coordinates all parsing.
    func parse(ocrText: String) -> ParsedReceiptData {
        var parsedData = ParsedReceiptData()
        
        parsedData.amount = findTotalAmount(in: ocrText)
        parsedData.date = findDate(in: ocrText)
        parsedData.merchant = findMerchant(in: ocrText)
        // Cash App / P2P style heuristics
        let cash = parseCashAppHints(in: ocrText)
        if parsedData.merchant == nil, let toName = cash.toName { parsedData.merchant = toName }
        if parsedData.purpose == nil, let purpose = cash.purpose { parsedData.purpose = purpose }
        if parsedData.paymentMethod == nil, let source = cash.paymentSource { parsedData.paymentMethod = source }
        
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
        
        // Enhanced fallback: Look for payment app patterns
        let paymentAppPatterns = [
            "Payment to", "Payment between", "To:", "From:",
            "Cash App", "Venmo", "PayPal", "Zelle"
        ]
        
        for line in lines {
            let lineText = String(line).trimmingCharacters(in: .whitespaces)
            
            // Skip time patterns (like "11:26")
            if lineText.matchesRegex(#"^\d{1,2}:\d{2}$"#) {
                continue
            }
            
            // Skip dollar amounts
            if lineText.matchesRegex(#"^\$[\d,]+\.?\d*$"#) {
                continue
            }
            
            // Look for payment app indicators
            for pattern in paymentAppPatterns {
                if lineText.localizedCaseInsensitiveContains(pattern) {
                    // Extract the name after the pattern
                    if let range = lineText.range(of: pattern, options: .caseInsensitive) {
                        let afterPattern = String(lineText[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        if !afterPattern.isEmpty && !afterPattern.matchesRegex(#"^\d"#) {
                            print("Found merchant from payment pattern: \(afterPattern)")
                            return afterPattern
                        }
                    }
                }
            }
            
            // If line looks like a name (not time, not amount, not empty)
            if !lineText.isEmpty && 
               !lineText.matchesRegex(#"^\d{1,2}:\d{2}$"#) && 
               !lineText.matchesRegex(#"^\$[\d,]+\.?\d*$"#) &&
               !lineText.matchesRegex(#"^\d+$"#) &&
               lineText.count > 1 {
                print("Found merchant from fallback: \(lineText)")
                return lineText
            }
        }
        
        // Final fallback: If no organization is found, return the first non-empty line.
        return lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }).map(String.init)
    }

    /// Finds the total amount using a robust multi-pass strategy.
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
        
        // Pass 2: Look for payment app patterns (large amounts, often standalone)
        let paymentAppPattern = #"\$(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#
        do {
            let regex = try NSRegularExpression(pattern: paymentAppPattern)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            let amounts = results.compactMap { result -> Double? in
                guard result.numberOfRanges > 1 else { return nil }
                let amountString = nsString.substring(with: result.range(at: 1)).replacingOccurrences(of: ",", with: "")
                return Double(amountString)
            }
            
            // For payment apps, look for the largest amount (likely the main transaction)
            if let maxAmount = amounts.max(), maxAmount > 0 {
                print("Found payment app amount: \(maxAmount)")
                return maxAmount
            }
        } catch {
            print("Payment app regex error: \(error.localizedDescription)")
        }
        
        // Pass 3: If no keyword amount was found, fall back to the largest number on the receipt.
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
    
    // MARK: - Cash App / P2P helpers
    private func parseCashAppHints(in text: String) -> (toName: String?, purpose: String?, paymentSource: String?) {
        let lines = text
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        var toName: String?
        var purpose: String?
        var paymentSource: String?
        
        // Example patterns from Cash App screenshot
        // "Payment between" section often followed by lines: "To: Marcus Drummer" and "From: <name>"
        if let toLine = lines.first(where: { $0.lowercased().hasPrefix("to:") }) {
            toName = toLine.replacingOccurrences(of: "To:", with: "", options: [.caseInsensitive]).trimmingCharacters(in: .whitespaces)
        }
        if let forLine = lines.first(where: { $0.lowercased().hasPrefix("for ") }) {
            purpose = String(forLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }
        if let sourceIndex = lines.firstIndex(where: { $0.lowercased().contains("payment source") }) {
            if sourceIndex + 1 < lines.count {
                let next = lines[sourceIndex + 1]
                if !next.isEmpty { paymentSource = next }
            }
        }
        
        // Fallback: if "Payment source" not found, check for common banks in text
        if paymentSource == nil {
            let banks = ["Bank of America", "BofA", "Chase", "Wells Fargo", "Brex", "Amex", "Capital One"]
            for bank in banks {
                if text.localizedCaseInsensitiveContains(bank) { paymentSource = bank; break }
            }
        }
        
        return (toName, purpose, paymentSource)
    }
}