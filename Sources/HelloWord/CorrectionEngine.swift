import AppKit

enum CorrectionMode: Int, CaseIterable {
    case off
    case balanced
    case enhanced
    case wonderwriter

    var title: String {
        switch self {
        case .off: return "Correction Off"
        case .balanced: return "Balanced Correction"
        case .enhanced: return "Enhanced Local Correction"
        case .wonderwriter: return "Hello, Word Context — Offline"
        }
    }
}

final class LocalCorrectionEngine {
    var mode: CorrectionMode = .balanced

    private let replacements: [String: String] = [
        "adn": "and", "agian": "again", "alot": "a lot", "becuase": "because",
        "beleive": "believe", "calender": "calendar", "cemetary": "cemetery",
        "definately": "definitely", "definitly": "definitely", "enviroment": "environment",
        "existance": "existence", "experiance": "experience", "febuary": "February",
        "finaly": "finally", "foriegn": "foreign", "freind": "friend",
        "goverment": "government", "grammer": "grammar", "greatful": "grateful",
        "happend": "happened", "harrass": "harass", "immediatly": "immediately",
        "independant": "independent", "knowlege": "knowledge", "liason": "liaison",
        "maintainance": "maintenance", "neccessary": "necessary", "occured": "occurred",
        "occurrance": "occurrence", "posession": "possession", "prefered": "preferred",
        "priviledge": "privilege", "publically": "publicly", "recieve": "receive",
        "recomend": "recommend", "refered": "referred", "remeber": "remember",
        "seperate": "separate", "succesful": "successful", "supercede": "supersede",
        "teh": "the", "thier": "their", "tommorow": "tomorrow", "truely": "truly",
        "untill": "until", "wierd": "weird", "writting": "writing", "youre": "you're"
    ]

    func configure(_ textView: NSTextView) {
        let enabled = mode != .off
        textView.isContinuousSpellCheckingEnabled = enabled
        textView.isGrammarCheckingEnabled = enabled
        textView.isAutomaticSpellingCorrectionEnabled = mode == .balanced
        textView.isAutomaticTextCompletionEnabled = mode != .off
    }

    func correction(for word: String) -> String? {
        guard mode != .off, word.count > 1 else { return nil }

        let lower = word.lowercased()
        if let replacement = replacements[lower] {
            return matchCase(of: word, replacement: replacement)
        }

        guard mode == .enhanced, word.count >= 4, word.allSatisfy({ $0.isLetter }) else {
            return nil
        }

        let checker = NSSpellChecker.shared
        let fullRange = NSRange(location: 0, length: (word as NSString).length)
        let misspelled = checker.checkSpelling(of: word, startingAt: 0)
        guard misspelled.location != NSNotFound,
              misspelled.length == fullRange.length,
              let guess = checker.guesses(
                forWordRange: fullRange,
                in: word,
                language: nil,
                inSpellDocumentWithTag: 0
              )?.first,
              editDistance(lower, guess.lowercased()) <= 1 else {
            return nil
        }
        return matchCase(of: word, replacement: guess)
    }

    private func matchCase(of original: String, replacement: String) -> String {
        if original == original.uppercased() { return replacement.uppercased() }
        if original.first?.isUppercase == true {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    private func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, right) in b.enumerated() {
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + (left == right ? 0 : 1)
                )
            }
            previous = current
        }
        return previous[b.count]
    }
}
