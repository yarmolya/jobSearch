import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct WorkExperience: Identifiable {
    let id: String
    let position: String
    let company: String
    let field: String
    let specialization: String
    let startDate: Date
    let endDate: Date?
    let isCurrentJob: Bool
    let description: String
    
   
    var duration: Double {
        let end = endDate ?? Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day],
                                               from: startDate,
                                               to: end)
        
        let years = Double(components.year ?? 0)
        let months = Double(components.month ?? 0) / 12
        let days = Double(components.day ?? 0) / 365
        
        let total = years + months + days
        print("Duration calculated: \(total) years (\(components.year ?? 0)y \(components.month ?? 0)m \(components.day ?? 0)d)")
        return total
    }

    
 
    init(id: String = UUID().uuidString, position: String, company: String, field: String, specialization: String, startDate: Date, endDate: Date? = nil, isCurrentJob: Bool, description: String) {
        self.id = id
        self.position = position
        self.company = company
        self.field = field
        self.specialization = specialization
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrentJob = isCurrentJob
        self.description = description
    }
}



struct SelectedJobCategory: Identifiable {
    let id = UUID()
    let category: JobCategory
    var selectedFields: Set<JobCategory.Field>
    

    init(category: JobCategory, selectedFields: Set<JobCategory.Field> = []) {
        self.category = category
        self.selectedFields = selectedFields
    }
}


func parseWorkExperience(from dictArray: [[String: Any]]) -> [WorkExperience] {
    print("Parsing \(dictArray.count) work experience entries")
    
    var experiences: [WorkExperience] = []
    
    for dict in dictArray {
        print("Parsing dict: \(dict)")
    
        let id = dict["id"] as? String ?? UUID().uuidString
        let position = dict["position"] as? String ?? "Unknown Position"
        let company = dict["company"] as? String ?? "Unknown Company"
        let field = dict["field"] as? String ?? ""
        let specialization = dict["specialization"] as? String ?? ""
        let description = dict["description"] as? String ?? ""
        let isCurrentJob = dict["isCurrentJob"] as? Bool ?? false
        
       
        print("startDate type: \(type(of: dict["startDate"] ?? "nil"))")
        print("endDate type: \(type(of: dict["endDate"] ?? "nil"))")
        
    
        if let directDuration = dict["duration"] as? Double {
            print("Found direct duration: \(directDuration) years")
            let startDate = Calendar.current.date(byAdding: .year, value: -Int(ceil(directDuration)), to: Date()) ?? Date()
            let endDate = isCurrentJob ? nil : Date()
            experiences.append(WorkExperience(
                id: id,
                position: position,
                company: company,
                field: field,
                specialization: specialization,
                startDate: startDate,
                endDate: endDate,
                isCurrentJob: isCurrentJob,
                description: description
            ))
            continue
        }
        
        func parseDate(from value: Any?) -> Date? {
            guard let value = value else { return nil }
            
            if let timestamp = value as? Timestamp {
                return timestamp.dateValue()
            }
            
            if let dateString = value as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                let formats = [
                    "yyyy-MM-dd",
                    "yyyy/MM/dd",
                    "MM/dd/yyyy",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "MMMM d, yyyy 'at' h:mm:ss a 'UTC'Z"
                ]
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
            
            return nil
        }
        
        guard let startDate = parseDate(from: dict["startDate"]) else {
            print("⚠️ Could not parse startDate from: \(dict["startDate"] ?? "nil")")
            continue
        }
        
        let endDate = isCurrentJob ? nil : parseDate(from: dict["endDate"])
        
        experiences.append(WorkExperience(
            id: id,
            position: position,
            company: company,
            field: field,
            specialization: specialization,
            startDate: startDate,
            endDate: endDate,
            isCurrentJob: isCurrentJob,
            description: description
        ))
    }
    
    print("Successfully parsed \(experiences.count) work experiences")
    return experiences
}
