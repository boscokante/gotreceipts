import Foundation

struct SpeechParseResult {
    let memo: String
    let lastFour: String?
    let matchedCard: Card?
}

class SpeechParser {
    private let cardService: CardService
    
    init(cardService: CardService) {
        self.cardService = cardService
    }
    
    func parseSpeech(_ speech: String) -> SpeechParseResult {
        var memo = speech
        var lastFour: String?
        var matchedCard: Card?
        
        // Look for patterns like "ending in 1234", "card 1234", "1234", etc.
        let patterns = [
            #"(?:ending in|card|using|with)\s+(\d{4})"#,
            #"(\d{4})(?:\s|$)"#,
            #"(?:last four|last 4)\s+(\d{4})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: speech.utf16.count)
                if let match = regex.firstMatch(in: speech, options: [], range: range) {
                    let matchRange = match.range(at: 1)
                    if let swiftRange = Range(matchRange, in: speech) {
                        let foundLastFour = String(speech[swiftRange])
                        lastFour = foundLastFour
                        
                        // Try to find matching card
                        if let card = cardService.findCard(by: foundLastFour) {
                            matchedCard = card
                        }
                        
                        // Remove the card reference from memo
                        let fullMatchRange = match.range(at: 0)
                        if let fullSwiftRange = Range(fullMatchRange, in: speech) {
                            memo = speech.replacingOccurrences(of: String(speech[fullSwiftRange]), with: "", options: .caseInsensitive)
                            memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        break
                    }
                }
            }
        }
        
        return SpeechParseResult(memo: memo, lastFour: lastFour, matchedCard: matchedCard)
    }
    
    func findPotentialCards(in speech: String) -> [Card] {
        var potentialCards: [Card] = []
        
        // Extract all 4-digit numbers from speech
        let regex = try? NSRegularExpression(pattern: #"\b(\d{4})\b"#)
        let range = NSRange(location: 0, length: speech.utf16.count)
        
        regex?.enumerateMatches(in: speech, options: [], range: range) { match, _, _ in
            if let match = match, match.numberOfRanges > 1 {
                let matchRange = match.range(at: 1)
                if let swiftRange = Range(matchRange, in: speech) {
                    let lastFour = String(speech[swiftRange])
                    if let card = cardService.findCard(by: lastFour) {
                        potentialCards.append(card)
                    }
                }
            }
        }
        
        return potentialCards
    }
}
