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
    
    // Requirements
    var requiredEducationLevel: String
    var requiredWorkExperience: Double
    var requiresDriverLicense: Bool
    var studyField: String
    var specialization: String
    var requiredLanguages: [UserLanguage]
    
    // Location
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
    
    // Additional data
    var jobField: String
    var jobSpecialization: String
    var applicants: [String]
    var shortlistedApplicants: [String]
    
    // Added for distance calculation
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
        
        // Using correct field names for latitude and longitude
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
                
                // Create a Language object with the name (using same for both en and uk)
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
    
    // Enhanced matching function for more accurate job matching
    func matchesJobSeeker(jobSeeker: [String: Any]) -> Double {
        var score = 0.0
        var hasEssentialRequirements = true
        var hasDisqualifyingFactors = false
        
        let seekerPreferredFields = jobSeeker["preferredJobFields"] as? [String] ?? []
        let seekerPreferredSpecializations = jobSeeker["preferredJobFieldSpecializations"] as? [String] ?? []
        let allFieldsSelected = seekerPreferredFields.isEmpty
        
        // MARK: - CRITICAL FACTORS (Potential disqualifiers)
        
        // Driver's license check (if required but not available - disqualifying factor)
        let seekerHasLicense = jobSeeker["hasDriverLicense"] as? Bool ?? false
        if requiresDriverLicense && !seekerHasLicense {
            hasDisqualifyingFactors = true
        }
        
        // MARK: - DISTANCE MATCHING
        
        if let distance = distanceFromSeeker,
           let acceptableDistance = jobSeeker["acceptableDistance"] as? Double {
            
            if distance > acceptableDistance {
                // Distance is outside acceptable range - disqualifying factor
                score += 5
            } else {
                // Award points based on proximity (closer is better)
                // Maximum 30 points for being very close (less than 20% of acceptable distance)
                let distanceRatio = distance / acceptableDistance
                
                if distanceRatio < 0.2 {
                    // Very close - major bonus
                    score += 30
                } else if distanceRatio < 0.5 {
                    // Reasonably close - good bonus
                    score += 20
                } else if distanceRatio < 0.8 {
                    // Within range but further away - small bonus
                    score += 10
                } else {
                    // Far but still within range - no bonus
                    score += 5
                }
            }
        }
        
        // MARK: - EDUCATION MATCHING
        
        let seekerEducationLevel = jobSeeker["educationLevel"] as? String ?? ""
        
        if educationMatches(required: requiredEducationLevel, actual: seekerEducationLevel) {
            // Full match - significant bonus
            score += 15
        } else if requiredEducationLevel != "No education" {
            // Education requirement not met
            hasEssentialRequirements = false
        }
        
        // MARK: - WORK EXPERIENCE MATCHING
        
        let seekerExperience = jobSeeker["workExperience"] as? Double ?? 0.0
        
        // Experience match scoring with greater weight
        if requiredWorkExperience > 0 {
            if seekerExperience >= requiredWorkExperience {
                // Scale the score based on how much experience they have above the minimum
                let experienceRatio = min(seekerExperience / requiredWorkExperience, 2.0) // Cap at 2x required experience
                score += 20 * experienceRatio
            } else if seekerExperience > 0 {
                // Partial experience match (has some experience but not enough)
                let partialExperienceRatio = seekerExperience / requiredWorkExperience
                score += 10 * partialExperienceRatio
                
                // If they have less than half the required experience, mark as missing essential requirements
                if partialExperienceRatio < 0.5 {
                    hasEssentialRequirements = false
                }
            } else {
                // No experience when required
                hasEssentialRequirements = false
            }
        } else if seekerExperience > 0 {
            // Job doesn't require experience but candidate has some - small bonus
            score += 5
        }
        
        // MARK: - FIELD OF STUDY MATCHING
        
        let seekerStudyField = jobSeeker["studyField"] as? String ?? ""
        
        if !studyField.isEmpty {
            if seekerStudyField == studyField {
                // Direct field match
                score += 20
            } else if !seekerStudyField.isEmpty {
                // Has a different field - slight penalty
                score -= 10
            }
        }
        
        // MARK: - SPECIALIZATION MATCHING
        
        let seekerSpecialization = jobSeeker["specialization"] as? String ?? ""
        
        if !specialization.isEmpty {
            if seekerSpecialization == specialization {
                // Direct specialization match - major bonus
                score += 25
            } else if !seekerSpecialization.isEmpty {
                // Different specialization - minor penalty
                score -= 5
            }
        }
        
        
        // MARK: - JOB FIELD MATCHING

        if !allFieldsSelected && !jobField.isEmpty {
                // Check for matching job fields
                let fieldMatch = seekerPreferredFields.contains(jobField)
                
                if fieldMatch {
                    // Base field match bonus
                    score += 30
                    
                    // Check for specialization match if available
                    if !jobSpecialization.isEmpty {
                        let specializationMatch = seekerPreferredSpecializations.contains(jobSpecialization)
                        
                        if specializationMatch {
                            // Specialization match bonus (higher than field match alone)
                            score += 40
                        } else if !seekerPreferredSpecializations.isEmpty {
                            // Has preferred specializations but no match - small penalty
                            score -= 10
                        }
                    }
                } else {
                    // No field match - significant penalty
                    score -= 30
                    hasEssentialRequirements = false
                }
            } else if allFieldsSelected {
                // No specific preferences - small bonus
                score += 10
            }

        
        // MARK: - FINAL SCORE CALCULATION
        
        // Apply essential requirements filter
        if !hasEssentialRequirements {
            score = max(score - 40, 0) // Significant penalty for missing essential requirements
        }
        
        // Apply disqualifying factors
        if hasDisqualifyingFactors {
            score = 0 // Complete disqualification
        }
        
        return max(score, 0) // Ensure non-negative score
    }
    
    // Enhanced education level comparison
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
        
        // No education requirement or exact match
        if required == "No education" || required == actual {
            return true
        }
        
        // Check if seeker's education level is higher than required
        if let requiredIndex = educationLevels.firstIndex(of: required),
           let actualIndex = educationLevels.firstIndex(of: actual) {
            return actualIndex >= requiredIndex
        }
        
        return false
    }
}

// Helper function to calculate distance between two coordinates
func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    // Create CLLocation objects
    let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
    
    // Calculate distance in meters and convert to kilometers
    return fromLocation.distance(from: toLocation) / 1000.0
}

class VacancyViewModel: ObservableObject {
    @Published var vacancies: [Vacancy] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    
    // Key for UserDefaults to store IDs of vacancies the user has interacted with
    private let interactedVacanciesKey = "interactedVacancies"
    
    // Get list of vacancies that the user has already interacted with
    private func getInteractedVacancies(for userId: String) -> [String] {
        let key = "\(interactedVacanciesKey)_\(userId)"
        return userDefaults.stringArray(forKey: key) ?? []
    }
    
    // Add a vacancy to the list of interacted vacancies
    private func addToInteractedVacancies(vacancyId: String, userId: String) {
        let key = "\(interactedVacanciesKey)_\(userId)"
        var interactedVacancies = getInteractedVacancies(for: userId)
        
        if !interactedVacancies.contains(vacancyId) {
            interactedVacancies.append(vacancyId)
            userDefaults.set(interactedVacancies, forKey: key)
        }
    }
    
    // Завантаження всіх активних вакансій
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
     
     // Завантаження вакансій для конкретного роботодавця
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
     
    
    // Add a minimum score threshold for matching vacancies
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
        
        // Get the job seeker's preferred job fields and specializations
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
                
                var perfectMatches: [Vacancy] = [] // Both field and specialization match
                var goodMatches: [Vacancy] = []   // Only field matches
                var potentialMatches: [Vacancy] = []    // Other matches
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    let id = document.documentID

                    // Skip already interacted vacancies
                    if excludingIds.contains(id) {
                        continue
                    }

                    var vacancy = Vacancy(id: id, data: data)
                    
                    // Check if job is remote
                    let isRemoteJob = vacancy.jobType == "Remote"
                    
                    // For remote jobs, only check country match
                    if isRemoteJob {
                        if vacancy.countryPlaceId == seekerCountryPlaceId {
                            // Calculate match score without distance consideration
                            let matchScore = vacancy.matchesJobSeeker(jobSeeker: jobSeekerData)
                            
                            if matchScore >= self.minimumMatchScore {
                                // Check if job field matches
                                let doesFieldMatch = allFieldsSelected || seekerPreferredFields.contains(vacancy.jobField)
                                
                                // Check if specialization matches (if available)
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
                        // For non-remote jobs, proceed with distance check as before
                        if let jobCoord = vacancy.coordinates {
                            let distance = calculateDistance(from: seekerCoord, to: jobCoord)
                            vacancy.distanceFromSeeker = distance
                            
                            // Only include vacancies within acceptable distance
                            if distance <= acceptableDistance {
                                // Calculate match score
                                let matchScore = vacancy.matchesJobSeeker(jobSeeker: jobSeekerData)
                                
                                if matchScore >= self.minimumMatchScore {
                                    // Check if job field matches
                                    let doesFieldMatch = allFieldsSelected || seekerPreferredFields.contains(vacancy.jobField)
                                    
                                    // Check if specialization matches (if available)
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
                
                // Sort each category by match score and distance
                perfectMatches.sort { (v1, v2) -> Bool in
                    let score1 = v1.matchesJobSeeker(jobSeeker: jobSeekerData)
                    let score2 = v2.matchesJobSeeker(jobSeeker: jobSeekerData)
                    
                    // For remote jobs, don't consider distance in sorting
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
                    
                    // For remote jobs, don't consider distance in sorting
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
                    
                    // For remote jobs, don't consider distance in sorting
                    if v1.jobType != "Remote" && v2.jobType != "Remote",
                       abs(score1 - score2) < 10,
                       let d1 = v1.distanceFromSeeker,
                       let d2 = v2.distanceFromSeeker {
                        return d1 < d2
                    }
                    return score1 > score2
                }
                
                // Combine all matches with perfect matches first
                let allMatches = perfectMatches + goodMatches + potentialMatches
                
                DispatchQueue.main.async {
                    self.vacancies = allMatches
                    completion()
                }
            }
    }
    
    // Method to toggle application for a vacancy
    func toggleApplication(vacancyId: String, jobSeekerId: String, apply: Bool, completion: @escaping (Bool) -> Void) {
        // Mark this vacancy as interacted with, regardless of whether applying or rejecting
        addToInteractedVacancies(vacancyId: vacancyId, userId: jobSeekerId)
        
        // If not applying (i.e., rejecting), don't need to update Firestore
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
            
            // Add job seeker to the list if not already present
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
    
    // Method to record that a user has rejected a vacancy (without changing anything in Firestore)
    func recordRejection(vacancyId: String, userId: String) {
        addToInteractedVacancies(vacancyId: vacancyId, userId: userId)
    }
    
    // Method to deactivate a vacancy
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
    
    // Method to update a vacancy
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

    // Method to get a single vacancy
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

