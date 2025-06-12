import SwiftUI
import Firebase
import FirebaseFirestore

class TopsisRankingViewModel: ObservableObject {
    @Published var candidates: [TopsisCandidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCandidate: TopsisCandidate?
    
    func loadCandidates(vacancyId: String) {
        print("🚀 Starting to load candidates for vacancy: \(vacancyId)")
        isLoading = true
        candidates = []
        
        let db = Firestore.firestore()
        
       
        db.collection("vacancies").document(vacancyId).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                print("❌ Error fetching vacancy: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists,
                  let vacancyData = document.data() else {
                self.isLoading = false
                self.errorMessage = "Vacancy not found"
                print("❌ Vacancy document doesn't exist or has no data")
                return
            }
            
            let topsisWeights = vacancyData["topsisWeights"] as? [String: Double] ?? [
                "educationWeight": 0.2,
                "experienceWeight": 0.2,
                "fieldMatchWeight": 0.2,
                "skillsWeight": 0.2,
                "locationWeight": 0.2
            ]
            print("⚖️ Using TOPSIS weights: \(topsisWeights)")
            
            db.collection("vacancies").document(vacancyId).collection("applicants").getDocuments { querySnapshot, error in
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Error fetching applicants: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.isLoading = false
                    print("⚠️ No applicant documents found")
                    return
                }
                
                let dispatchGroup = DispatchGroup()
                var allCandidates: [[String: Any]] = []
                
                for document in documents {
                    let candidateId = document.documentID
                    var baseData = document.data()
                    baseData["jobSeekerId"] = candidateId
                    
                    print("\n👤 Processing candidate: \(candidateId)")
                    
                    dispatchGroup.enter()
                    self.fetchCandidateDetails(candidateId: candidateId, vacancyId: vacancyId) { extraData in
                       
                        var fullCandidateData = baseData
                        fullCandidateData.merge(extraData) { current, _ in current } 
                        
                        allCandidates.append(fullCandidateData)
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    print("🎉 All candidates processed: \(allCandidates.count)")
                    
                    let topsisCalculator = TopsisCalculator(weights: topsisWeights)
                    let rankedCandidates = topsisCalculator.rankCandidates(
                        vacancyData: vacancyData,
                        candidates: allCandidates
                    )
                    
                    let rankedIds = rankedCandidates.map { $0.id }
                    print("🏆 Ranking results: \(rankedIds)")
                    
                    db.collection("vacancies").document(vacancyId).updateData([
                        "rankedApplicants": rankedIds
                    ]) { error in
                        if let error = error {
                            print("❌ Error updating ranked applicants: \(error.localizedDescription)")
                        } else {
                            print("✅ Successfully updated ranked applicants")
                        }
                    }
                    
                    self.candidates = rankedCandidates
                    self.isLoading = false
                    print("🏁 Finished loading and ranking candidates")
                }
            }
        }
    }
    
    private func fetchCandidateDetails(candidateId: String, vacancyId: String, completion: @escaping ([String: Any]) -> Void) {
        let db = Firestore.firestore()
        var candidateData: [String: Any] = [:]
        let dispatchGroup = DispatchGroup()
        
        
        dispatchGroup.enter()
        db.collection("vacancies").document(vacancyId).collection("applicants").document(candidateId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                candidateData = data
            }
            dispatchGroup.leave()
        }
        
        
        dispatchGroup.enter()
        db.collection("job_seekers").document(candidateId).collection("workExperiences").getDocuments { snapshot, error in
            if let experiences = snapshot?.documents.map({ $0.data() }) {
                candidateData["workExperiences"] = experiences
            } else {
                candidateData["workExperiences"] = []
            }
            dispatchGroup.leave()
        }
        
        
        dispatchGroup.enter()
        db.collection("job_seekers").document(candidateId).collection("languages").getDocuments { snapshot, error in
            if let languages = snapshot?.documents.map({ $0.data() }) {
                candidateData["languages"] = languages
            } else {
                candidateData["languages"] = []
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(candidateData)
        }
    }
}
