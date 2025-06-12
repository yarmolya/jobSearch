import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UniformTypeIdentifiers
import QuickLook

struct JobSeekerHomeView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var userName: String = ""
    @State private var userPhoto: URL?
    @State private var isLoading = true
    @State private var showingMatchView = false
    @State private var showingProfileEditView = false
    @State private var showingSurveyEditView = false
    @State private var showingCVUploadView = false
    @State private var userProfile: [String: Any] = [:]
    @State private var hasCV: Bool = false
    @State private var recentApplications: [JobApplication] = []
    @State private var isLoadingApplications = false
    @State private var showingHistoryView = false
    @State private var localizedCity: String = ""
    @State private var localizedCountry: String = ""
    @State private var shouldNavigateToAuth = false
    
    var isUkrainian: Bool {
        languageManager.selectedLanguage == "uk"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            welcomeSection
                            userActionsSection
                            recentApplicationsSection
                            profileSummarySection
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            .navigationTitle("") 
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    logoutButton
                }
            }
            .navigationDestination(isPresented: $showingMatchView) {
                JobSeekerMatchView()
            }
            .navigationDestination(isPresented: $showingProfileEditView) {
                JobSeekerProfileEditorView(
                    firstName: userProfile["firstName"] as? String ?? "",
                    lastName: userProfile["lastName"] as? String ?? "",
                    email: userProfile["email"] as? String ?? "",
                    phoneNumber: userProfile["phoneNumber"] as? String ?? "",
                    bio: userProfile["bio"] as? String ?? ""
                )
            }
            .navigationDestination(isPresented: $showingSurveyEditView) {
                OnboardingSurveyView()
            }
            .navigationDestination(isPresented: $showingCVUploadView) {
                CVUploadView()
            }
            .navigationDestination(isPresented: $showingHistoryView) {
                JobApplicationHistoryView()
            }
            .navigationDestination(isPresented: $shouldNavigateToAuth) {
                RootView()
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                fetchUserData()
                fetchRecentApplications()
            }
        }
    }
    
   
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your dashboard...".localized())
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                if let photoURL = userPhoto {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hello,".localized())
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(userName)
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                }
            }
            
            Text("Find your perfect job match today".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.top)
    }
    
    var userActionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showingMatchView = true
            } label: {
                HStack {
                    Image(systemName: "briefcase.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.trailing, 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find Jobs".localized())
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Explore job matches".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            Button {
                showingProfileEditView = true
            } label: {
                HStack {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.trailing, 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit Profile".localized())
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Update your personal information".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            Button {
                showingSurveyEditView = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.trailing, 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit Job Preferences".localized())
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Update your skills and preferences".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            Button {
                showingCVUploadView = true
            } label: {
                HStack {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.trailing, 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasCV ? "Update CV".localized() : "Upload CV".localized())
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(hasCV ? "Manage your CV".localized() : "Upload your CV".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.horizontal)
    }
    
    var recentApplicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Applications".localized())
                    .font(.headline)
                
                Spacer()
                
                if !recentApplications.isEmpty {
                    Button("View All".localized()) {
                        showingHistoryView = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            Group {
                if isLoadingApplications {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(height: 100)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                } else if recentApplications.isEmpty {
                    emptyApplicationsView
                } else {
                    applicationsListView
                }
            }
        }
        .padding(.horizontal)
    }
    
    var applicationsListView: some View {
        VStack(spacing: 0) {
            ForEach(recentApplications) { application in
                ApplicationRowView(application: application)
                    .padding(.horizontal, 12)
                
                if application.id != recentApplications.last?.id {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    var emptyApplicationsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            
            Text("No applications yet".localized())
                .font(.subheadline)
            
            Button {
                showingMatchView = true
            } label: {
                Text("Find Jobs".localized())
                    .font(.caption)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    var profileSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Profile Summary".localized())
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SummaryRowView(
                    label: "Education".localized(),
                    value: (userProfile["educationLevel"] as? String)?.localized() ?? "Not specified".localized(),
                    iconName: "graduationcap.fill"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                SummaryRowView(
                    label: "Location".localized(),
                    value: "\(localizedCity), \(localizedCountry)",
                    iconName: "mappin.and.ellipse"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                SummaryRowView(
                    label: "Experience".localized(),
                    value: formatExperience(userProfile["workExperience"] as? Double ?? 0),
                    iconName: "clock.fill"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                SummaryRowView(
                    label: "License".localized(),
                    value: (userProfile["hasDriverLicense"] as? Bool ?? false) ? "Yes".localized() : "No".localized(),
                    iconName: "car.fill"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                SummaryRowView(
                    label: "CV Status".localized(),
                    value: hasCV ? "Uploaded".localized() : "Not uploaded".localized(),
                    iconName: "doc.text.fill"
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    var profileButton: some View {
        Button {
            showingProfileEditView = true
        } label: {
            if let photoURL = userPhoto {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } placeholder: {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var logoutButton: some View {
        Button(action: logout) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.title3)
                .foregroundColor(.red)
        }
        .alert("Logout".localized(), isPresented: $showingLogoutAlert) {
            Button("Cancel".localized(), role: .cancel) {}
            Button("Logout".localized(), role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to log out?".localized())
        }
    }
    
    
    
    @State private var showingLogoutAlert = false
    
    func logout() {
        showingLogoutAlert = true
    }
    
    func performLogout() {
        guard Auth.auth().currentUser != nil else {
            print("⚠️ User already logged out")
            return
        }
        
        do {
            try Auth.auth().signOut()
            print("✅ Successfully logged out")
            
            DispatchQueue.main.async {
                self.shouldNavigateToAuth = true
            }
        } catch let signOutError as NSError {
            print("❌ Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
   
    func fetchUserData() {
            guard let currentUser = Auth.auth().currentUser else {
                    print("❌ No authenticated user found")
                    isLoading = false
                    return
                }
                
                let uid = currentUser.uid
                
                guard !uid.isEmpty else {
                    print("❌ UID is empty")
                    isLoading = false
                    return
                }
                
                print("✅ Fetching data for UID: \(uid)")
                
            
            let db = Firestore.firestore()
            
            db.collection("job_seekers").document(uid).getDocument { snapshot, error in
                if let error = error {
                    print("❌ Error fetching profile: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                if let data = snapshot?.data() {
                    let firstName = data["firstName"] as? String ?? ""
                    let lastName = data["lastName"] as? String ?? ""
                    self.userName = "\(firstName) \(lastName)"
                    
                    if let photoURLString = data["photoURL"] as? String,
                       let url = URL(string: photoURLString) {
                        self.userPhoto = url
                    }
                    
                    self.hasCV = (data["resumeURL"] as? String) != nil
                    self.userProfile = data
                    
                  
                    let viewModel = CitySearchViewModel()
                    
                   
                    let group = DispatchGroup()
                    
                    if let cityID = data["city_place_id"] as? String {
                        group.enter()
                        viewModel.fetchLocalizedName(for: cityID) { name in
                            DispatchQueue.main.async {
                                self.localizedCity = name ?? ""
                                group.leave()
                            }
                        }
                    }
                    
                    if let countryID = data["country_place_id"] as? String {
                        group.enter()
                        viewModel.fetchLocalizedName(for: countryID) { name in
                            DispatchQueue.main.async {
                                self.localizedCountry = name ?? ""
                                group.leave()
                            }
                        }
                    }
                    
                
                    group.notify(queue: .main) {
                        self.isLoading = false
                    }
                } else {
                    print("❌ Profile data not found")
                    isLoading = false
                }
            }
        }
        
        func refreshData() async {
           
            try? await Task.sleep(nanoseconds: 800_000_000)
            fetchUserData()
            fetchRecentApplications()
        }
        
        func fetchRecentApplications() {
            guard let uid = Auth.auth().currentUser?.uid else {
                return
            }
            
            isLoadingApplications = true
            let db = Firestore.firestore()
            let interactionsRef = db.collection("job_seekers").document(uid).collection("job_interactions")
            
            interactionsRef.order(by: "timestamp", descending: true).limit(to: 3).getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching job interactions: \(error.localizedDescription)")
                    isLoadingApplications = false
                    return
                }
                
                let dispatchGroup = DispatchGroup()
                var applications: [(index: Int, application: JobApplication)] = []
                
                if let documents = snapshot?.documents {
                    for (index, document) in documents.enumerated() {
                        dispatchGroup.enter()
                        
                        let data = document.data()
                        let vacancyId = document.documentID
                        
                       
                        db.collection("vacancies").document(vacancyId).getDocument { vacancySnapshot, _ in
                            var vacancyStatus: String? = nil
                            
                            if let vacancyData = vacancySnapshot?.data() {
                                vacancyStatus = vacancyData["status"] as? String
                            }
                            
                            var applicationData = data
                            applicationData["vacancyStatus"] = vacancyStatus
                            
                            let application = JobApplication(id: vacancyId, data: applicationData)
                            applications.append((index: index, application: application))
                            dispatchGroup.leave()
                        }
                    }
                    
                    dispatchGroup.notify(queue: .main) {
                       
                        self.recentApplications = applications.sorted { $0.index < $1.index }.map { $0.application }
                        self.isLoadingApplications = false
                    }
                } else {
                    self.isLoadingApplications = false
                }
            }
        }
        
        func formatExperience(_ years: Double) -> String {
            if years == 0 {
                return "No experience".localized()
            } else if years < 1 {
                let months = Int(years * 12)
                let monthKey = months == 1 ? "month" : "months"
                return String(format: "%d %@", months, monthKey.localized())
            } else if years == floor(years) {
                let wholeYears = Int(years)
                let yearKey = wholeYears == 1 ? "year" : "years"
                return String(format: "%d %@", wholeYears, yearKey.localized())
            } else {
                let wholeYears = Int(floor(years))
                let months = Int((years - Double(wholeYears)) * 12)
                let yearKey = wholeYears == 1 ? "year" : "years"
                let monthKey = months == 1 ? "month" : "months"
                return String(format: "%d %@ %d %@", wholeYears, yearKey.localized(), months, monthKey.localized())
            }
        }
    }



struct SummaryRowView: View {
    let label: String
    let value: String
    let iconName: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value.isEmpty ? "Not specified".localized() : value)
                    .font(.body)
            }
            
            Spacer()
        }
        .padding()
    }
}
