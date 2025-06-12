import SwiftUI
import FirebaseFirestore
import FirebaseAuth

extension DateFormatter {
    static func localizedFormatter(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style = .none) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale(identifier: LanguageManager.shared.selectedLanguage) 
        return formatter
    }
}



struct JobApplication: Identifiable {
    let id: String
    let jobTitle: String
    let companyName: String
    let status: String 
    let timestamp: Date
    let vacancyStatus: String? 
    
    
    var displayStatus: String {
        if status == "applied" && vacancyStatus == "active" {
            return "applied"
        } else {
            return "closed"
        }
    }

    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.jobTitle = data["jobTitle"] as? String ?? "Unknown Job"
        self.companyName = data["companyName"] as? String ?? "Unknown Company"
        self.status = data["status"] as? String ?? "unknown"
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.vacancyStatus = data["vacancyStatus"] as? String
    }
}


struct StatusBadge: View {
    let status: String 
    
    var body: some View {
        Text(status.capitalized.localized())
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
    
    var backgroundColor: Color {
        status == "applied" ? .green : .gray
    }
}


struct JobApplicationHistoryView: View {
    @State private var applications: [JobApplication] = []
    @State private var isLoading = true
    @State private var filterStatus: String? = nil
    
    var filteredApplications: [JobApplication] {
        switch filterStatus {
        case "applied":
            return applications.filter { $0.displayStatus == "applied" }
        case "closed":
            return applications.filter { $0.displayStatus == "closed" }
        default:
            return applications
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if applications.isEmpty {
                emptyStateView
            } else {
                applicationsList
            }
        }
        .navigationTitle("Application History".localized())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                filterMenu
            }
        }
        .onAppear {
            fetchApplicationHistory()
        }
    }
    
   
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your application history...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No applications yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("You haven't applied to any jobs yet. Start exploring job matches to apply.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var applicationsList: some View {
        List {
            ForEach(filteredApplications.sorted(by: { $0.timestamp > $1.timestamp })) { application in
                ApplicationRowView(application: application)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var filterMenu: some View {
        Menu {
            Button {
                filterStatus = nil
            } label: {
                Label("All".localized(), systemImage: filterStatus == nil ? "checkmark" : "")
            }
            
            Button {
                filterStatus = "applied"
            } label: {
                Label("Applied".localized(), systemImage: filterStatus == "applied" ? "checkmark" : "")
            }
            
            Button {
                filterStatus = "closed"
            } label: {
                Label("Closed".localized(), systemImage: filterStatus == "closed" ? "checkmark" : "")
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    

    
    private func fetchApplicationHistory() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        let interactionsRef = db.collection("job_seekers").document(uid).collection("job_interactions")
        
        interactionsRef.getDocuments { snapshot, error in
            isLoading = false
            
            if let error = error {
                print("Error fetching job interactions: \(error.localizedDescription)")
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var applications: [JobApplication] = []
            
            if let documents = snapshot?.documents {
                for document in documents {
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
                        applications.append(application)
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    self.applications = applications
                }
            }
        }
    }
}


struct ApplicationRowView: View {
    let application: JobApplication
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(application.jobTitle)
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: application.displayStatus)
            }
            
            Text(application.companyName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(DateFormatter.localizedFormatter(dateStyle: .short).string(from: application.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            if application.displayStatus == "closed" {
                Text("Job no longer available".localized())
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { showingDetails = true }
        .sheet(isPresented: $showingDetails) {
            ApplicationDetailView(application: application)
        }
    }
}


struct ApplicationDetailView: View {
    let application: JobApplication
    @State private var localizedCity: String = ""
    @State private var localizedCountry: String = ""
    @State private var vacancy: Vacancy?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingDetailView
                } else if let vacancy = vacancy {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            applicationHeaderView
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Job Details")
                                    .font(.headline)
                                
                                jobDetailBlock(vacancy: vacancy)
                            }
                        }
                        .padding()
                    }
                } else {
                    noDetailsView
                }
            }
            .navigationTitle("Application Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                fetchVacancyDetails()
            }
        }
    }
    
  
    
    private var loadingDetailView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading job details...".localized())
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var noDetailsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Job details not available".localized())
                .font(.headline)
            
            Text("The job details for this application could not be found. The job posting may have been removed.".localized())
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var applicationHeaderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(application.jobTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                StatusBadge(status: application.displayStatus)
            }
            
            Text(application.companyName)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text("Applied on".localized())
                    .foregroundColor(.secondary)
                Text(DateFormatter.localizedFormatter(dateStyle: .long).string(from: application.timestamp))
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            
            if application.displayStatus == "applied" {
                Text("Your application was submitted successfully. The employer will contact you if they're interested in your profile.".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                Text("This job is no longer available. The posting may have been removed or closed.".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func jobDetailBlock(vacancy: Vacancy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !vacancy.jobType.isEmpty {
                detailItem(icon: "briefcase.fill", title: "Job Type".localized(), value: (vacancy.jobType).localized())
            }
            
            if !vacancy.city.isEmpty {
                detailItem(icon: "mappin.and.ellipse", title: "Location".localized(), value: "\(localizedCity), \(localizedCountry)")
            }
            
            if !vacancy.salaryRange.isEmpty {
                detailItem(icon: "dollarsign.circle.fill", title: "Salary".localized(), value: vacancy.salaryRange)
            }
            
            if !vacancy.jobDescription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description".localized())
                        .font(.headline)
                    
                    Text(vacancy.jobDescription)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func detailItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
        }
    }
    
 
    
    private func fetchVacancyDetails() {
        isLoading = true
        let db = Firestore.firestore()
        let viewModel = CitySearchViewModel() 
        
        db.collection("vacancies").document(application.id).getDocument {snapshot, error in
            
            self.isLoading = false
            
            if let error = error {
                print("Error fetching vacancy: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No data found for vacancy")
                return
            }
            
           
            self.vacancy = Vacancy(id: self.application.id, data: data)
            
        
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
        }
    }
    
}

