//
//  NERNaturalLanguage.swift
//  GotReceipts
//
//  Created by Bosco "Bosko" Kante on 9/26/25.
//
import NaturalLanguage

func extractEntities(from text: String) -> (people: [String], orgs: [String], places: [String]) {
    let tagger = NLTagger(tagSchemes: [.nameType])
    tagger.string = text
    var people = [String](), orgs = [String](), places = [String]()
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
        guard let tag = tag else { return true }
        let token = String(text[range])
        switch tag {
        case .personalName: people.append(token)
        case .organizationName: orgs.append(token)
        case .placeName: places.append(token)
        default: break
        }
        return true
    }
    return (Array(Set(people)), Array(Set(orgs)), Array(Set(places)))
}

