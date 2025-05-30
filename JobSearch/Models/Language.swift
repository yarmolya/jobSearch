import Foundation

struct Language: Identifiable, Codable, Hashable {
    var id: String { en }
    let en: String
    let uk: String
    
    var displayName: String {
        LanguageManager.shared.selectedLanguage == "uk" ? uk : en
        }
}

// Proficiency levels
enum ProficiencyLevel: String, Codable, CaseIterable, Identifiable {
    case motherTongue = "Mother Tongue"
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
    
    var id: String { rawValue }
    
    var localizedString: String {
        switch self {
        case .motherTongue: return "Mother Tongue".localized()
        default: return rawValue
        }
    }
    
    // Numeric value for sorting
    var sortOrder: Int {
        switch self {
        case .motherTongue: return 7
        case .a1: return 1
        case .a2: return 2
        case .b1: return 3
        case .b2: return 4
        case .c1: return 5
        case .c2: return 6
        }
    }
}

// User's language with proficiency
struct UserLanguage: Identifiable, Codable, Hashable {
    var id: String
    var language: Language
    var proficiency: ProficiencyLevel
    
    var displayName: String {
        language.displayName
    }

    init(id: String = UUID().uuidString, language: Language, proficiency: ProficiencyLevel) {
        self.id = id
        self.language = language
        self.proficiency = proficiency
    }
}
