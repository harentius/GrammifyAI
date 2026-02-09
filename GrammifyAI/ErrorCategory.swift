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

        switch language.lowercased() {
        case "english", "en":
            return base + [.TNS, .ASP, .ART]
        case "german", "de":
            return base + [.GEN, .CAS, .ADJ, .V_POS]
        default:
            return base
        }
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
