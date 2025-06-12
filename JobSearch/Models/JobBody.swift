import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

struct Vacancy: Identifiable {
    var id: String
    var employerId: String
    var companyName: String
    var jobTitle: String
    var jobDescription: String
    var salaryRange: String
    var jobType: String
    var createdAt: Date
    var deadlineDate: Date
    var status: String
    
    
    var requiredEducationLevel: String
    var requiredWorkExperience: Double
    var requiresDriverLicense: Bool
    var studyField: String
    var specialization: String
    var requiredLanguages: [UserLanguage]
    

    var country: String
    var city: String
    var cityLatitude: Double?
    var cityLongitude: Double?
    var cityPlaceId: String?
    var countryPlaceId: String?
    var coordinates: CLLocationCoordinate2D? {
        if let lat = cityLatitude, let lng = cityLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return nil
    }
    
  
    var jobField: String
    var jobSpecialization: String
    var applicants: [String]
    var shortlistedApplicants: [String]
    

    var distanceFromSeeker: Double?
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.employerId = data["employerId"] as? String ?? ""
        self.companyName = data["companyName"] as? String ?? ""
        self.jobTitle = data["jobTitle"] as? String ?? ""
        self.jobDescription = data["jobDescription"] as? String ?? ""
        self.salaryRange = data["salaryRange"] as? String ?? ""
        self.jobType = data["jobType"] as? String ?? ""
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let deadline = data["deadlineDate"] as? Timestamp {
            self.deadlineDate = deadline.dateValue()
        } else {
            self.deadlineDate = Date().addingTimeInterval(30*24*60*60)
        }
        
        self.status = data["status"] as? String ?? "active"
        
        self.requiredEducationLevel = data["requiredEducationLevel"] as? String ?? ""
        self.requiredWorkExperience = data["requiredWorkExperience"] as? Double ?? 0.0
        self.requiresDriverLicense = data["requiresDriverLicense"] as? Bool ?? false
        self.studyField = data["studyField"] as? String ?? ""
        self.specialization = data["specialization"] as? String ?? ""
        
        self.country = data["country"] as? String ?? ""
        self.city = data["city"] as? String ?? ""
        
     
        self.cityLatitude = data["city_latitude"] as? Double
        self.cityLongitude = data["city_longitude"] as? Double
        
        self.cityPlaceId = data["city_place_id"] as? String
        self.countryPlaceId = data["country_place_id"] as? String
        
        self.jobField = data["jobField"] as? String ?? ""
        self.jobSpecialization = data["jobSpecialization"] as? String ?? ""
        self.applicants = data["applicants"] as? [String] ?? []
        self.shortlistedApplicants = data["shortlistedApplicants"] as? [String] ?? []
        if let languagesData = data["requiredLanguages"] as? [[String: Any]] {
            self.requiredLanguages = languagesData.compactMap { langData in
                guard let languageDict = langData["language"] as? [String: String],
                      let proficiencyString = langData["proficiency"] as? String,
                      let proficiency = ProficiencyLevel(rawValue: proficiencyString) else {
                    return nil
                }
                
              
                let language = Language(en: languageDict["en"] ?? "", uk: languageDict["uk"] ?? "")
                
                return UserLanguage(
                    id: UUID().uuidString,
                    language: language,
                    proficiency: proficiency
                )
            }
        } else {
            self.requiredLanguages = []
        }
    }
    
 
    func matchesJobSeeker(jobSeeker: [String: Any]) -> Double {
        var score = 0.0
        var hasEssentialRequirements = true
        var hasDisqualifyingFactors = false
        
        let seekerPreferredFields = jobSeeker["preferredJobFields"] as? [String] ?? []
        let seekerPreferredSpecializations = jobSeeker["preferredJobFieldSpecializations"] as? [String] ?? []
        let allFieldsSelected = seekerPreferredFields.isEmpty
        
    
        
        
        let seekerHasLicense = jobSeeker["hasDriverLicense"] as? Bool ?? false
        if requiresDriverLicense && !seekerHasLicense {
            hasDisqualifyingFactors = true
        }
        
   
        
        if let distance = distanceFromSeeker,
           let acceptableDistance = jobSeeker["acceptableDistance"] as? Double {
            
            if distance > acceptableDistance {
               
                score += 5
            } else {
              
                let distanceRatio = distance / acceptableDistance
                
                if distanceRatio < 0.2 {
                  
                    score += 30
                } else if distanceRatio < 0.5 {
                    
                    score += 20
                } else if distanceRatio < 0.8 {
                    
                    score += 10
                } else {
                    
                    score += 5
                }
            }
        }
        

        
        let seekerEducationLevel = jobSeeker["educationLevel"] as? String ?? ""
        
        if educationMatches(required: requiredEducationLevel, actual: seekerEducationLevel) {
           
            score += 15
        } else if requiredEducationLevel != "No education" {
           
            hasEssentialRequirements = false
        }
        
      
        
        let seekerExperience = jobSeeker["workExperience"] as? Double ?? 0.0
        
       
        if requiredWorkExperience > 0 {
            if seekerExperience >= requiredWorkExperience {
               
                let experienceRatio = min(seekerExperience / requiredWorkExperience, 2.0) 
                score += 20 * experienceRatio
            } else if seekerExperience > 0 {
                
                let partialExperienceRatio = seekerExperience / requiredWorkExperience
                score += 10 * partialExperienceRatio
                
             
                if partialExperienceRatio < 0.5 {
                    hasEssentialRequirements = false
                }
            } else {
               
                hasEssentialRequirements = false
            }
        } else if seekerExperience > 0 {
         
            score += 5
        }

        
        let seekerStudyField = jobSeeker["studyField"] as? String ?? ""
        
        if !studyField.isEmpty {
            if seekerStudyField == studyField {
              
                score += 20
            } else if !seekerStudyField.isEmpty {
             
                score -= 10
            }
        }
        
  
        
        let seekerSpecialization = jobSeeker["specialization"] as? String ?? ""
        
        if !specialization.isEmpty {
            if seekerSpecialization == specialization {
               
                score += 25
            } else if !seekerSpecialization.isEmpty {
               
                score -= 5
            }
        }
        
        
   

        if !allFieldsSelected && !jobField.isEmpty {
           
                let fieldMatch = seekerPreferredFields.contains(jobField)
                
                if fieldMatch {
               
                    score += 30
                    
                    
                    if !jobSpecialization.isEmpty {
                        let specializationMatch = seekerPreferredSpecializations.contains(jobSpecialization)
                        
                        if specializationMatch {
                        
                            score += 40
                        } else if !seekerPreferredSpecializations.isEmpty {
                            
                            score -= 10
                        }
                    }
                } else {
                  
                    score -= 30
                    hasEssentialRequirements = false
                }
            } else if allFieldsSelected {
                
                score += 10
            }

        
    
        
       
        if !hasEssentialRequirements {
            score = max(score - 40, 0) 
        }
 
        if hasDisqualifyingFactors {
            score = 0 
        }
        
        return max(score, 0)
    }
    
   
    private func educationMatches(required: String, actual: String) -> Bool {
        let educationLevels = [
            "No education",
            "Secondary",
            "Vocational",
            "Technical",
            "Bachelor",
            "Master",
            "Doctoral"
        ]
        
       
        if required == "No education" || required == actual {
            return true
        }
        
      
        if let requiredIndex = educationLevels.firstIndex(of: required),
           let actualIndex = educationLevels.firstIndex(of: actual) {
            return actualIndex >= requiredIndex
        }
        
        return false
    }
}


func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {

    let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
    

    return fromLocation.distance(from: toLocation) / 1000.0
}

class VacancyViewModel: ObservableObject {
    @Published var vacancies: [Vacancy] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    
   
    private let interactedVacanciesKey = "interactedVacancies"
    

    private func getInteractedVacancies(for userId: String) -> [String] {
        let key = "\(interactedVacanciesKey)_\(userId)"
        return userDefaults.stringArray(forKey: key) ?? []
    }
    
  
    private func addToInteractedVacancies(vacancyId: String, userId: String) {
        let key = "\(interactedVacanciesKey)_\(userId)"
        var interactedVacancies = getInteractedVacancies(for: userId)
        
        if !interactedVacancies.contains(vacancyId) {
            interactedVacancies.append(vacancyId)
            userDefaults.set(interactedVacancies, forKey: key)
        }
    }

     func loadVacancies() {
         isLoading = true
         errorMessage = nil
         
         db.collection("vacancies")
             .whereField("status", isEqualTo: "active")
             .whereField("deadlineDate", isGreaterThan: Timestamp(date: Date()))
             .getDocuments { (querySnapshot, error) in
                 self.isLoading = false
                 
                 if let error = error {
                     self.errorMessage = "Failed to load vacancies: \(error.localizedDescription)"
                     return
                 }
                 
                 var newVacancies: [Vacancy] = []
                 for document in querySnapshot?.documents ?? [] {
                     let vacancy = Vacancy(id: document.documentID, data: document.data())
                     newVacancies.append(vacancy)
                 }
                 
                 self.vacancies = newVacancies
             }
     }
     
   
     func loadEmployerVacancies(employerId: String) {
         isLoading = true
         errorMessage = nil
         
         db.collection("vacancies")
             .whereField("employerId", isEqualTo: employerId)
             .getDocuments { (querySnapshot, error) in
                 self.isLoading = false
                 
                 if let error = error {
                     self.errorMessage = "Failed to load vacancies: \(error.localizedDescription)"
                     return
                 }
                 
                 var newVacancies: [Vacancy] = []
                 for document in querySnapshot?.documents ?? [] {
                     let vacancy = Vacancy(id: document.documentID, data: document.data())
                     newVacancies.append(vacancy)
                 }
                 
                 self.vacancies = newVacancies
             }
     }
     
    
 
    private let minimumMatchScore: Double = 30.0
    
    func loadMatchingVacancies(for jobSeekerData: [String: Any], excludingIds: [String], completion: @escaping () -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let seekerLat = jobSeekerData["city_latitude"] as? Double,
              let seekerLon = jobSeekerData["city_longitude"] as? Double,
              let acceptableDistance = jobSeekerData["acceptableDistance"] as? Double,
              let seekerCountryPlaceId = jobSeekerData["country_place_id"] as? String else {
            print("Missing seeker location or distance")
            self.vacancies = []
            isLoading = false
            completion()
            return
        }
        
       
        let seekerPreferredFields = jobSeekerData["preferredJobFields"] as? [String] ?? []
        let seekerPreferredSpecializations = jobSeekerData["preferredJobFieldSpecializations"] as? [String] ?? []
        let allFieldsSelected = seekerPreferredFields.isEmpty
        
        let seekerCoord = CLLocationCoordinate2D(latitude: seekerLat, longitude: seekerLon)

        db.collection("vacancies")
            .whereField("status", isEqualTo: "active")
            .whereField("deadlineDate", isGreaterThan: Timestamp(date: Date()))
            .getDocuments { (snapshot, error) in
                self.isLoading = false
                
                if let error = error {
                    print("Error loading vacancies: \(error.localizedDescription)")
                    self.errorMessage = "Failed to load vacancies: \(error.localizedDescription)"
                    self.vacancies = []
                    completion()
                    return
                }
                
                var perfectMatches: [Vacancy] = [] 
                var goodMatches: [Vacancy] = []  
                var potentialMatches: [Vacancy] = []   
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    let id = document.documentID

                 
                    if excludingIds.contains(id) {
                        continue
                    }

                    var vacancy = Vacancy(id: id, data: data)
                    
                
                    let isRemoteJob = vacancy.jobType == "Remote"
                    
                 
                    if isRemoteJob {
                        if vacancy.countryPlaceId == seekerCountryPlaceId {
                          
                            let matchScore = vacancy.matchesJobSeeker(jobSeeker: jobSeekerData)
                            
                            if matchScore >= self.minimumMatchScore {
                                
                                let doesFieldMatch = allFieldsSelected || seekerPreferredFields.contains(vacancy.jobField)
                                
                             
                                let doesSpecializationMatch = vacancy.jobSpecialization.isEmpty ||
                                    seekerPreferredSpecializations.contains(vacancy.jobSpecialization)
                                
                                if doesFieldMatch && doesSpecializationMatch {
                                    perfectMatches.append(vacancy)
                                } else if doesFieldMatch {
                                    goodMatches.append(vacancy)
                                } else {
                                    potentialMatches.append(vacancy)
                                }
                            }
                        }
                    } else {
                   
                        if let jobCoord = vacancy.coordinates {
                            let distance = calculateDistance(from: seekerCoord, to: jobCoord)
                            vacancy.distanceFromSeeker = distance
                            
                        
                            if distance <= acceptableDistance {
                        
                                let matchScore = vacancy.matchesJobSeeker(jobSeeker: jobSeekerData)
                                
                                if matchScore >= self.minimumMatchScore {
                               
                                    let doesFieldMatch = allFieldsSelected || seekerPreferredFields.contains(vacancy.jobField)
                                    
                                
                                    let doesSpecializationMatch = vacancy.jobSpecialization.isEmpty ||
                                        seekerPreferredSpecializations.contains(vacancy.jobSpecialization)
                                    
                                    if doesFieldMatch && doesSpecializationMatch {
                                        perfectMatches.append(vacancy)
                                    } else if doesFieldMatch {
                                        goodMatches.append(vacancy)
                                    } else {
                                        potentialMatches.append(vacancy)
                                    }
                                }
                            }
                        }
                    }
                }
                
             
                perfectMatches.sort { (v1, v2) -> Bool in
                    let score1 = v1.matchesJobSeeker(jobSeeker: jobSeekerData)
                    let score2 = v2.matchesJobSeeker(jobSeeker: jobSeekerData)
                    
                    
                    if v1.jobType != "Remote" && v2.jobType != "Remote",
                       abs(score1 - score2) < 10,
                       let d1 = v1.distanceFromSeeker,
                       let d2 = v2.distanceFromSeeker {
                        return d1 < d2
                    }
                    return score1 > score2
                }
                
                goodMatches.sort { (v1, v2) -> Bool in
                    let score1 = v1.matchesJobSeeker(jobSeeker: jobSeekerData)
                    let score2 = v2.matchesJobSeeker(jobSeeker: jobSeekerData)
                    
                  
                    if v1.jobType != "Remote" && v2.jobType != "Remote",
                       abs(score1 - score2) < 10,
                       let d1 = v1.distanceFromSeeker,
                       let d2 = v2.distanceFromSeeker {
                        return d1 < d2
                    }
                    return score1 > score2
                }
                
                potentialMatches.sort { (v1, v2) -> Bool in
                    let score1 = v1.matchesJobSeeker(jobSeeker: jobSeekerData)
                    let score2 = v2.matchesJobSeeker(jobSeeker: jobSeekerData)
                    
                  
                    if v1.jobType != "Remote" && v2.jobType != "Remote",
                       abs(score1 - score2) < 10,
                       let d1 = v1.distanceFromSeeker,
                       let d2 = v2.distanceFromSeeker {
                        return d1 < d2
                    }
                    return score1 > score2
                }
                
        
                let allMatches = perfectMatches + goodMatches + potentialMatches
                
                DispatchQueue.main.async {
                    self.vacancies = allMatches
                    completion()
                }
            }
    }
    

    func toggleApplication(vacancyId: String, jobSeekerId: String, apply: Bool, completion: @escaping (Bool) -> Void) {
       
        addToInteractedVacancies(vacancyId: vacancyId, userId: jobSeekerId)
        
    
        if !apply {
            completion(true)
            return
        }
        
        let vacancyRef = db.collection("vacancies").document(vacancyId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let vacancyDocument: DocumentSnapshot
            
            do {
                try vacancyDocument = transaction.getDocument(vacancyRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var applicants = vacancyDocument.data()?["applicants"] as? [String] else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to fetch applicants array"
                ])
                errorPointer?.pointee = error
                return nil
            }
            
        
            if !applicants.contains(jobSeekerId) {
                applicants.append(jobSeekerId)
            }
            
            transaction.updateData(["applicants": applicants], forDocument: vacancyRef)
            return nil
            
        }) { (_, error) in
            if let error = error {
                print("❌ Transaction failed: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Transaction successfully committed!")
                completion(true)
            }
        }
    }
    

    func recordRejection(vacancyId: String, userId: String) {
        addToInteractedVacancies(vacancyId: vacancyId, userId: userId)
    }
    
 
    func deactivateVacancy(vacancyId: String, completion: @escaping (Bool) -> Void) {
        db.collection("vacancies").document(vacancyId).updateData([
            "status": "inactive"
        ]) { error in
            if let error = error {
                print("❌ Error updating vacancy status: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Vacancy deactivated successfully")
                completion(true)
            }
        }
    }
    
    func activateVacancy(vacancyId: String, completion: @escaping (Bool) -> Void) {
        db.collection("vacancies").document(vacancyId).updateData([
            "status": "active",
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("❌ Error activating vacancy: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Vacancy activated successfully")
                completion(true)
            }
        }
    }

    func updateVacancy(vacancyId: String, data: [String: Any], completion: @escaping (Bool) -> Void) {
        db.collection("vacancies").document(vacancyId).updateData(data) { error in
            if let error = error {
                print("❌ Error updating vacancy: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Vacancy updated successfully")
                completion(true)
            }
        }
    }
    
    func deleteVacancy(vacancyId: String, completion: @escaping (Bool) -> Void) {
        db.collection("vacancies").document(vacancyId).delete { error in
            if let error = error {
                print("❌ Error deleting vacancy: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Vacancy deleted successfully")
                // Remove the vacancy from the local array
                if let index = self.vacancies.firstIndex(where: { $0.id == vacancyId }) {
                    self.vacancies.remove(at: index)
                }
                completion(true)
            }
        }
    }


    func getVacancy(vacancyId: String, completion: @escaping (Vacancy?) -> Void) {
        db.collection("vacancies").document(vacancyId).getDocument { document, error in
            if let error = error {
                print("❌ Error getting vacancy: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                print("❌ Vacancy document does not exist")
                completion(nil)
                return
            }
            
            let vacancy = Vacancy(id: document.documentID, data: data)
            completion(vacancy)
        }
    }

    
    
}

