import Foundation

struct StudyCategory: Identifiable, Codable, Hashable {
    var id: String { category_en } 
    let category_en: String
    let category_uk: String
    let fields: [Field]

    struct Field: Identifiable, Codable, Hashable {
        var id: String { en }
        let en: String
        let uk: String
    }
}

