import Foundation
import SwiftData

// Error categories for grammar correction
enum ErrorCategory: String, Codable, CaseIterable {
    // Universal categories (Base Schema)
    case SYN = "SYN" // Syntax: Sentence structure, word order
    case VOC = "VOC" // Vocabulary: Wrong word choice, false friends
    case PREP = "PREP" // Prepositions: Wrong prepositions
    case IDM = "IDM" // Idiomatics: Not idiomatic expressions
    case REG = "REG" // Register: Too formal/informal
    case ORT = "ORT" // Orthography: Spelling/typos

    // German-specific categories
    case GEN = "GEN" // Genus: Der/Die/Das logic
    case CAS = "CAS" // Case: Noun/article declension (Dativ, Akkusativ)
    case ADJ = "ADJ" // Adjective endings: Complex endings (-e, -en, -er, -es)
    case V_POS = "V-POS" // Verb Position: V2 vs. VE in main/subordinate clauses

    // English-specific categories
    case TNS = "TNS" // Tenses: Tense forms
    case ASP = "ASP" // Aspect: Progressive vs. Simple
    case ART = "ART" // Articles: a/an/the/zero article

    var description: String {
        switch self {
        case .SYN: return "Syntax"
        case .VOC: return "Vocabulary"
        case .PREP: return "Prepositions"
        case .IDM: return "Idiomatics"
        case .REG: return "Register"
        case .ORT: return "Orthography"
        case .GEN: return "Genus"
        case .CAS: return "Case"
        case .ADJ: return "Adjective Endings"
        case .V_POS: return "Verb Position"
        case .TNS: return "Tenses"
        case .ASP: return "Aspect"
        case .ART: return "Articles"
        }
    }

    // Get categories for a specific language
    static func categoriesForLanguage(_ language: String) -> [ErrorCategory] {
        let base: [ErrorCategory] = [.SYN, .VOC, .PREP, .IDM, .REG, .ORT]

        switch normalizeLanguage(language) {
        case "english":
            return base + [.TNS, .ASP, .ART]
        case "german":
            return base + [.GEN, .CAS, .ADJ, .V_POS]
        default:
            return base
        }
    }

    // Normalize language strings (e.g. "en", "EN-US", "English" -> "english")
    static func normalizeLanguage(_ language: String) -> String {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "unknown" }

        switch trimmed {
        case "en", "eng", "en-us", "en-gb", "en_us", "en_gb", "english":
            return "english"
        case "de", "deu", "ger", "de-de", "de-at", "de-ch", "de_de", "deutsch", "german":
            return "german"
        default:
            return trimmed
        }
    }

    // Flexible parser for LLM category strings (handles "syn", "V_POS", "SYN (Syntax)", "Syntax")
    static func from(_ rawString: String) -> ErrorCategory? {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .uppercased()
            .replacingOccurrences(of: "_", with: "-")

        if let exact = ErrorCategory(rawValue: normalized) {
            return exact
        }

        // Handle formats like "SYN (Syntax)" or "V-POS - Verb Position"
        if let firstToken = normalized.components(separatedBy: CharacterSet(charactersIn: " (:")).first,
           let tokenMatch = ErrorCategory(rawValue: firstToken) {
            return tokenMatch
        }

        // Match by description name (e.g. "Syntax", "Verb Position")
        if let descMatch = ErrorCategory.allCases.first(where: {
            $0.description.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return descMatch
        }

        return nil
    }
}

// Represents a detected error with its category and context
@Model
final class CorrectionError {
    var category: ErrorCategory
    var originalFragment: String?
    var correctedFragment: String?

    init(category: ErrorCategory, originalFragment: String? = nil, correctedFragment: String? = nil) {
        self.category = category
        self.originalFragment = originalFragment
        self.correctedFragment = correctedFragment
    }
}
