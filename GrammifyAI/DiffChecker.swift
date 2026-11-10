import Foundation
import SwiftDiff

struct DiffChecker {
    public static func diffCheck(incorrectString: String, correctString: String) -> AttributedString {
        let diffs = wordDiff(text1: incorrectString, text2: correctString)
        var correctAttributedString = AttributedString()

        for el in diffs {
            var fragment: AttributedString

            switch el {
            case .equal(let text):
                fragment = AttributedString(text)
            case .insert(let text):
                fragment = AttributedString(text)
                fragment.foregroundColor = .green
            case .delete(let text):
                fragment = AttributedString(text)
                fragment.foregroundColor = .red
                fragment.strikethroughColor = .red
                fragment.strikethroughStyle = .single
            }

            correctAttributedString = correctAttributedString + fragment
        }

        return correctAttributedString
    }

    private static func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber
    }

    private static func tokenize(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let chars = Array(text)
        var tokens: [String] = []
        var currentWord = ""

        for i in chars.indices {
            let char = chars[i]
            let isInternalApostrophe = (char == "'" || char == "\u{2019}")
                && i > 0 && isWordCharacter(chars[i - 1])
                && (i + 1) < chars.count && isWordCharacter(chars[i + 1])

            if isWordCharacter(char) || isInternalApostrophe {
                currentWord.append(char)
            } else {
                if !currentWord.isEmpty {
                    tokens.append(currentWord)
                    currentWord = ""
                }
                tokens.append(String(char))
            }
        }

        if !currentWord.isEmpty {
            tokens.append(currentWord)
        }

        return tokens
    }

    private static func wordDiff(text1: String, text2: String) -> [Diff] {
        let tokens1 = tokenize(text1)
        let tokens2 = tokenize(text2)

        var tokenToScalar: [String: UnicodeScalar] = [:]
        var scalarToToken: [UnicodeScalar: String] = [:]
        var nextCodePoint: UInt32 = 0xE000

        func allocateScalar(for token: String) -> UnicodeScalar {
            if let existing = tokenToScalar[token] {
                return existing
            }
            if nextCodePoint == 0xF900 {
                nextCodePoint = 0xF0000
            }
            let scalar = UnicodeScalar(nextCodePoint) ?? UnicodeScalar(0xFFFD)!
            nextCodePoint += 1
            tokenToScalar[token] = scalar
            scalarToToken[scalar] = token
            return scalar
        }

        var encoded1 = String.UnicodeScalarView()
        encoded1.reserveCapacity(tokens1.count)
        for token in tokens1 {
            encoded1.append(allocateScalar(for: token))
        }

        var encoded2 = String.UnicodeScalarView()
        encoded2.reserveCapacity(tokens2.count)
        for token in tokens2 {
            encoded2.append(allocateScalar(for: token))
        }

        let rawDiffs = diff(text1: String(encoded1), text2: String(encoded2))

        return rawDiffs.map { element in
            let decoded = element.text.unicodeScalars.compactMap { scalarToToken[$0] }.joined()
            return element.with(text: decoded)
        }
    }
}
