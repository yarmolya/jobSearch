import SwiftUI
import Firebase
import FirebaseAuth
import CoreLocation

struct JobSeekerMatchView: View {
    @StateObject private var vacancyViewModel = VacancyViewModel()
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var isLoading = true
    @State private var showingNoMoreCards = false
    @State private var isProcessingCard = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if vacancyViewModel.vacancies.isEmpty {
                    emptyStateView
                } else {
                    cardStack
                }
            }
            .navigationTitle("Job Matches".localized())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadMatchingVacancies()
            }
            .alert("No More Jobs".localized(), isPresented: $showingNoMoreCards) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You've gone through all available job postings. Check back later for new opportunities!".localized())
            }
        }
    }
    
    var background: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Finding your matches...".localized())
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No job matches found".localized())
                .font(.system(.title2, design: .rounded))
                .fontWeight(.medium)
            
            Text("We couldn't find any job vacancies matching your profile. Try updating your skills or preferences.".localized())
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                isLoading = true
                loadMatchingVacancies()
            } label: {
                Text("Refresh".localized())
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 10)
        }
    }
    
    var cardStack: some View {
        ZStack {
            ForEach(vacancyViewModel.vacancies.indices.prefix(3).reversed(), id: \.self) { index in
                if index >= currentIndex && index < currentIndex + 3 && index < vacancyViewModel.vacancies.count {
                    let vacancy = vacancyViewModel.vacancies[index]
                    
                    JobCardView(vacancy: vacancy)
                        .offset(index == currentIndex ? offset : .zero)
                        .rotationEffect(.degrees(Double(index == currentIndex ? offset.width / 20 : 0)))
                        .scaleEffect(index == currentIndex ? 1 : 0.95 - 0.05 * Double(index - currentIndex))
                        .opacity(index == currentIndex ? 1 : 0.7 - 0.3 * Double(index - currentIndex))
                        .zIndex(Double(vacancyViewModel.vacancies.count - index))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if index == currentIndex && !isProcessingCard {
                                        offset = gesture.translation
                                    }
                                }
                                .onEnded { gesture in
                                    if index == currentIndex && !isProcessingCard {
                                        handleCardSwipe(gesture: gesture, vacancy: vacancy)
                                    }
                                }
                        )
                        .animation(.spring(), value: offset)
                        .animation(.spring(), value: currentIndex)
                }
            }
            
            if !vacancyViewModel.vacancies.isEmpty &&
                currentIndex < vacancyViewModel.vacancies.count &&
                !isProcessingCard {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 60) {
                        Button {
                            if currentIndex < vacancyViewModel.vacancies.count {
                                let vacancy = vacancyViewModel.vacancies[currentIndex]
                                handleRejectAction(vacancy: vacancy)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isProcessingCard)
                        
                        Button {
                            if currentIndex < vacancyViewModel.vacancies.count {
                                let vacancy = vacancyViewModel.vacancies[currentIndex]
                                handleApplyAction(vacancy: vacancy)
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.green)
                                .clipShape(Circle())
                                .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isProcessingCard)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    
    func handleCardSwipe(gesture: DragGesture.Value, vacancy: Vacancy) {
        withAnimation(.spring()) {
            if gesture.translation.width > 100 {
               
                isProcessingCard = true
                offset = CGSize(width: 500, height: 0)
                applyForJob(vacancy)
            } else if gesture.translation.width < -100 {
               
                isProcessingCard = true
                offset = CGSize(width: -500, height: 0)
                rejectJob(vacancy)
            } else {
              
                offset = .zero
            }
        }
    }
    
   
    func handleRejectAction(vacancy: Vacancy) {
        withAnimation(.spring()) {
            isProcessingCard = true
            offset = CGSize(width: -500, height: 0)
            rejectJob(vacancy)
        }
    }
    
    
    func handleApplyAction(vacancy: Vacancy) {
        withAnimation(.spring()) {
            isProcessingCard = true
            offset = CGSize(width: 500, height: 0)
            applyForJob(vacancy)
        }
    }
    
    func loadMatchingVacancies() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("job_seekers").document(uid).getDocument { document, error in
            guard let jobSeekerData = document?.data() else {
                self.isLoading = false
                return
            }
            
            
            self.loadUserInteractionHistory { interactionHistory in
                
                self.vacancyViewModel.loadMatchingVacancies(for: jobSeekerData, excludingIds: interactionHistory) {
                    self.isLoading = false
                    self.currentIndex = 0
                    self.offset = .zero
                    
                   
                    if self.vacancyViewModel.vacancies.isEmpty {
                       
                    }
                }
            }
        }
    }
    
    func loadUserInteractionHistory(completion: @escaping ([String]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        let db = Firestore.firestore()
        let interactionsRef = db.collection("job_seekers").document(uid).collection("job_interactions")
        
        interactionsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching job interactions: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let interactedJobIds = snapshot?.documents.compactMap { $0.documentID } ?? []
            completion(interactedJobIds)
        }
    }
    
    func moveToNextCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring()) {
                offset = .zero
                
               
                if currentIndex < self.vacancyViewModel.vacancies.count - 1 {
                    currentIndex += 1
                } else {
                    
                    showingNoMoreCards = true
                    
                   
                    currentIndex = self.vacancyViewModel.vacancies.count 
                }
                
               
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isProcessingCard = false
                }
            }
        }
    }
    
    func rejectJob(_ vacancy: Vacancy) {
        guard let uid = Auth.auth().currentUser?.uid else {
            isProcessingCard = false
            return
        }
        
        
        let db = Firestore.firestore()
        let interactionRef = db.collection("job_seekers").document(uid).collection("job_interactions").document(vacancy.id)
        
        let interactionData: [String: Any] = [
            "status": "rejected",
            "timestamp": Timestamp(date: Date()),
            "jobTitle": vacancy.jobTitle,
            "companyName": vacancy.companyName
        ]
        
        interactionRef.setData(interactionData) { error in
            if let error = error {
                print("Error storing job rejection: \(error.localizedDescription)")
            } else {
                print("Successfully recorded rejection for vacancy \(vacancy.id)")
            }
            moveToNextCard()
        }
    }
    
    func applyForJob(_ vacancy: Vacancy) {
        guard let uid = Auth.auth().currentUser?.uid else {
            isProcessingCard = false
            return
        }
        
        let db = Firestore.firestore()
        let jobSeekerRef = db.collection("job_seekers").document(uid)
        
        
        jobSeekerRef.getDocument { document, error in
            guard let jobSeekerData = document?.data(), error == nil else {
                print("❌ Failed to fetch job seeker data")
                isProcessingCard = false
                return
            }

            

            var preferredFields: [String] = []
            var preferredSpecializations: [String] = []

            if let preferredJobFields = jobSeekerData["preferredJobFields"] as? [[String: Any]] {
                print("🔍 Processing preferredJobFields in applyForJob: \(preferredJobFields)")
                
                for fieldGroup in preferredJobFields {
                   
                    if let category = fieldGroup["category"] as? String {
                        preferredFields.append(category)
                    }
                    
                   
                    if let specializationsAny = fieldGroup["preferredJobFieldSpecializations"] {
                       
                        if let specializations = specializationsAny as? [String] {
                            preferredSpecializations.append(contentsOf: specializations)
                        } else if let specializationsArray = specializationsAny as? NSArray {
                            let stringArray = specializationsArray.compactMap { $0 as? String }
                            preferredSpecializations.append(contentsOf: stringArray)
                        } else {
                            print("⚠️ Unexpected specializations format: \(type(of: specializationsAny))")
                            print("Value: \(specializationsAny)")
                        }
                    }
                }
            } else {
                print("❌ No preferredJobFields found in jobSeekerData")
                print("Available keys: \(jobSeekerData.keys)")
            }

            print("✅ Extracted in applyForJob:")
            print("   • Fields: \(preferredFields)")
            print("   • Specializations: \(preferredSpecializations)")

            var applicantData: [String: Any] = [
                "jobSeekerId": uid,
                "firstName": jobSeekerData["firstName"] as? String ?? "",
                "lastName": jobSeekerData["lastName"] as? String ?? "",
                "email": jobSeekerData["email"] as? String ?? "",
                "phone": jobSeekerData["phone"] as? String ?? "",
                "bio": jobSeekerData["bio"] as? String ?? "",
                "location": jobSeekerData["city"] as? String ?? "",
                "skills": jobSeekerData["skills"] as? [String] ?? [],
                "educationLevel": jobSeekerData["educationLevel"] as? String ?? "",
                "studyField": jobSeekerData["studyField"] as? String ?? "",
                "specialization": jobSeekerData["specialization"] as? String ?? "",
                "workExperience": jobSeekerData["workExperience"] as? Double ?? 0,
                "resumeURL": jobSeekerData["resumeURL"] as? String ?? "",
                "appliedDate": Timestamp(date: Date()),
                "status": "pending",
                "preferredJobFields": preferredFields,
                "preferredJobFieldSpecializations": preferredSpecializations, 
            ]
            
            let group = DispatchGroup()
            
            
            group.enter()
            jobSeekerRef.collection("workExperiences").getDocuments { snapshot, error in
                if error != nil {
                    print("⚠️ Failed to fetch work experiences")
                }
                applicantData["workExperiences"] = snapshot?.documents.map { $0.data() } ?? []
                group.leave()
            }
            
           
            group.enter()
            jobSeekerRef.collection("languages").getDocuments { snapshot, error in
                if error != nil {
                    print("⚠️ Failed to fetch languages")
                }
                applicantData["languages"] = snapshot?.documents.map { $0.data() } ?? []
                group.leave()
            }
            
           
            group.notify(queue: .main) {
                let applicantRef = db.collection("vacancies").document(vacancy.id).collection("applicants").document(uid)
                
                applicantRef.setData(applicantData) { error in
                    if let error = error {
                        print("❌ Error storing applicant data: \(error.localizedDescription)")
                        isProcessingCard = false
                        return
                    }
                    
                    print("✅ Successfully stored applicant data for vacancy \(vacancy.id)")
                    
                   
                    let interactionRef = db.collection("job_seekers").document(uid).collection("job_interactions").document(vacancy.id)
                    
                    let interactionData: [String: Any] = [
                        "status": "applied",
                        "timestamp": Timestamp(date: Date()),
                        "jobTitle": vacancy.jobTitle,
                        "companyName": vacancy.companyName,
                        "fieldMatch": preferredFields.contains(vacancy.jobField),
                        "specializationMatch": !vacancy.jobSpecialization.isEmpty &&
                        preferredSpecializations.contains(vacancy.jobSpecialization)
                    ]
                    
                    interactionRef.setData(interactionData) { error in
                        if let error = error {
                            print("⚠️ Error storing interaction data: \(error.localizedDescription)")
                        }
                     
                        self.vacancyViewModel.toggleApplication(vacancyId: vacancy.id, jobSeekerId: uid, apply: true) { success in
                            if success {
                                print("✅ Successfully marked as applied")
                                moveToNextCard()
                            } else {
                                isProcessingCard = false
                            }
                        }
                    }
                }
            }
        }
    }
}
struct JobCardView: View {
    let vacancy: Vacancy
    @State private var showFullDescription = false
    @State private var localizedCity: String = ""
    @State private var localizedCountry: String = ""
    @StateObject private var jobFieldVM = JobFieldViewModel()
    @ObservedObject var languageManager = LanguageManager.shared
    
    var isUkrainian: Bool {
            languageManager.selectedLanguage == "uk"
        }
    
    private var translatedJobField: String {
        guard !vacancy.jobField.isEmpty else { return "" }
        
       
        let jobField = vacancy.jobField.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if let category = jobFieldVM.categories.first(where: {
            $0.category_en.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == jobField
        }) {
            return isUkrainian ? category.category_uk : category.category_en
        }
        
       
        print("Could not find matching category for: \(vacancy.jobField)")
        print("Available categories: \(jobFieldVM.categories.map { $0.category_en })")
        
        return vacancy.jobField
    }
        
    private var translatedJobSpecialization: String {
        guard !vacancy.jobSpecialization.isEmpty else { return "" }
        
     
        let jobField = vacancy.jobField.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let specialization = vacancy.jobSpecialization.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if let category = jobFieldVM.categories.first(where: {
            $0.category_en.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == jobField
        }) {
            if let field = category.fields.first(where: {
                $0.en.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == specialization
            }) {
                return isUkrainian ? field.uk : field.en
            } else {
                print("Could not find matching specialization in category \(category.category_en)")
                print("Available fields: \(category.fields.map { $0.en })")
            }
        }
        
        return vacancy.jobSpecialization
    }
        
    
   
    
    var body: some View {
           VStack(alignment: .leading, spacing: 0) {
               VStack(alignment: .leading, spacing: 8) {
                   Text(vacancy.jobTitle)
                       .font(.system(.title2, design: .rounded))
                       .fontWeight(.bold)
                   
                   Text(vacancy.companyName)
                       .font(.system(.headline, design: .rounded))
                       .foregroundColor(.secondary)
                   
                   HStack {
                       Label(vacancy.jobType.localized(), systemImage: "building.2")
                       Spacer()
                       Label(locationText, systemImage: "mappin.and.ellipse")
                   }
                   .font(.system(.subheadline, design: .rounded))
                   .foregroundColor(.secondary)
                   .padding(.top, 4)
               }
               .padding()
               .background(Color.blue.opacity(0.1))
               .cornerRadius(12)
               
               ScrollView {
                   VStack(alignment: .leading, spacing: 16) {
                       VStack(alignment: .leading, spacing: 12) {
                           if !vacancy.salaryRange.isEmpty {
                               DetailRow(icon: "dollarsign.circle.fill", title: "Salary", detail: vacancy.salaryRange)
                           }
                           
                           DetailRow(icon: "calendar", title: "Deadline", detail: DateFormatter.localizedFormatter(dateStyle: .long).string(from: vacancy.deadlineDate))
                           
                           if !vacancy.requiredEducationLevel.isEmpty && vacancy.requiredEducationLevel != "No education" {
                               DetailRow(icon: "graduationcap.fill", title: "Required Education", detail: vacancy.requiredEducationLevel.localized())
                           }
                           
                           if vacancy.requiredWorkExperience > 0 {
                               let experienceText = ExperienceFormatter.formatExperience(vacancy.requiredWorkExperience)
                               DetailRow(icon: "clock.fill", title: "Experience", detail: experienceText)
                           }
                           
                           if !vacancy.jobField.isEmpty {
                               DetailRow(icon: "briefcase.fill", title: "Job Field", detail: translatedJobField)
                           }
                           
                           if !vacancy.jobSpecialization.isEmpty {
                               DetailRow(icon: "target", title: "Specialization", detail: translatedJobSpecialization)
                           }
                           
                           if !vacancy.requiredLanguages.isEmpty {
                               DetailRow(
                                   icon: "globe",
                                   title: "Required Languages",
                                   detail: vacancy.requiredLanguages.map {
                                       "\($0.language.displayName) (\($0.proficiency.localizedString))"
                                   }.joined(separator: ", ")
                               )
                           }
                       }
                       .padding(.bottom, 8)
                       
                       if !vacancy.jobDescription.isEmpty {
                           VStack(alignment: .leading, spacing: 6) {
                               Text("Job Description".localized())
                                   .font(.system(.headline, design: .rounded))
                               
                               Text(vacancy.jobDescription)
                                   .font(.system(.body, design: .rounded))
                                   .foregroundColor(.primary)
                                   .lineLimit(showFullDescription ? nil : 4)
                                   .animation(.easeInOut(duration: 0.3), value: showFullDescription)
                               
                               if vacancy.jobDescription.count > 200 {
                                   Button {
                                       withAnimation(.easeInOut(duration: 0.3)) {
                                           showFullDescription.toggle()
                                       }
                                   } label: {
                                       Text(showFullDescription ? "Show less".localized() : "Show more".localized())
                                           .font(.system(.subheadline, design: .rounded))
                                           .foregroundColor(.blue)
                                   }
                                   .padding(.top, 4)
                               }
                           }
                       }
                   }
                   .padding()
               }
           }
           .background(Color(.systemBackground))
           .cornerRadius(16)
           .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
           .padding(.horizontal, 20)
           .padding(.vertical, 40)
           .onAppear {
               fetchLocalizedLocationNames()
               jobFieldVM.loadFromJSON()
           }
       }
       
    
    
    private var locationText: String {
           if !localizedCity.isEmpty && !localizedCountry.isEmpty {
               return "\(localizedCity), \(localizedCountry)"
           } else if !vacancy.city.isEmpty && !vacancy.country.isEmpty {
               return "\(vacancy.city), \(vacancy.country)"
           } else {
               return vacancy.city.isEmpty ? vacancy.country : vacancy.city
           }
       }
       
       private func fetchLocalizedLocationNames() {
           let viewModel = CitySearchViewModel()
           
           
           if let cityPlaceID = vacancy.cityPlaceId {
               viewModel.fetchLocalizedName(for: cityPlaceID) { name in
                   DispatchQueue.main.async {
                       self.localizedCity = name ?? vacancy.city
                   }
               }
           } else {
               self.localizedCity = vacancy.city
           }
           
 
           if let countryPlaceID = vacancy.countryPlaceId {
               viewModel.fetchLocalizedName(for: countryPlaceID) { name in
                   DispatchQueue.main.async {
                       self.localizedCountry = name ?? vacancy.country
                   }
               }
           } else {
               self.localizedCountry = vacancy.country
           }
       }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized())
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text(detail)
                    .font(.system(.subheadline, design: .rounded))
            }
        }
    }
}


struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > availableWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        y += rowHeight
        
        return CGSize(width: availableWidth, height: y)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let availableWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > availableWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
