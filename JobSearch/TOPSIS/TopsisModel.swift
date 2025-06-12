import SwiftUI
import Firebase
import FirebaseFirestore

struct TopsisCandidate: Identifiable, Comparable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let topsisScore: Double
    let absoluteScore: Double
    let educationScore: Double
    let experienceScore: Double
    let fieldMatchScore: Double
    let skillsScore: Double
    let locationScore: Double
    let educationLevel: String
    let experience: Double
    let location: String
    let hasDriverLicense: Bool
    let experienceField: String
    let experienceSpecialization: String
    let studyField: String
    let specialization: String
    let appliedDate: Date
    
    static func < (lhs: TopsisCandidate, rhs: TopsisCandidate) -> Bool {
        if lhs.topsisScore == rhs.topsisScore {
            return lhs.appliedDate > rhs.appliedDate 
        }
        return lhs.topsisScore < rhs.topsisScore
    }
    
    static func > (lhs: TopsisCandidate, rhs: TopsisCandidate) -> Bool {
        if lhs.topsisScore == rhs.topsisScore {
            return lhs.appliedDate < rhs.appliedDate 
        }
        return lhs.topsisScore > rhs.topsisScore
    }
}
