import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore



struct EmployerHomeView: View {
    
    @State private var companyName = ""
    @State private var contactPerson = ""
    @State private var description = ""
    @State private var website = ""
    @State private var profileImageURL: URL?
    @StateObject private var vacancyViewModel = VacancyViewModel()
    @State private var showingCreateVacancy = false
    @State private var showEditProfile = false
    @State private var showRanking = false
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    VStack(spacing: 16) {
                        if let url = profileImageURL {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "building.2.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .padding(20)
                                .foregroundColor(.blue)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Text(companyName)
                            .font(.title)
                            .bold()
                        
                        Text(description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if !website.isEmpty {
                            Link(destination: URL(string: website) ?? URL(string: "https://example.com")!) {
                                Text("🌐 \(website)")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        
                        Button {
                            showEditProfile = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile".localized())
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .padding(.top, 6)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                 
                    Button {
                        showingCreateVacancy = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add a job posting".localized())
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                   
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your vacancies".localized())
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if vacancyViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if vacancyViewModel.vacancies.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                
                                Text("You haven't posted any vacancies yet".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(vacancyViewModel.vacancies) { vacancy in
                                VacancyCard(vacancy: vacancy)
                                    .padding(.horizontal)
                                    .environmentObject(vacancyViewModel)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.vertical)
            }
            .navigationTitle("Company Profile".localized())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    logoutButton
                }
            }
            .onAppear {
                loadData()
                loadVacancies()
            }
            .sheet(isPresented: $showingCreateVacancy) {
                
                CreateJobVacancyView()
                    .onDisappear {
                        loadVacancies() 
                    }
            }
            .navigationDestination(isPresented: $showEditProfile) {
                EmployerProfileEditorView()
                    .onDisappear {
                        loadData() 
                    }
            }
            .navigationBarBackButtonHidden(true) 
            .refreshable {
                loadData()
                loadVacancies()
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
    

    
    func logout() {
        showingLogoutAlert = true
    }
    
    func performLogout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
    
    func loadData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("employers").document(uid).getDocument { document, error in
            if let data = document?.data() {
                self.companyName = data["companyName"] as? String ?? ""
                self.contactPerson = data["contactPerson"] as? String ?? ""
                self.description = data["description"] as? String ?? ""
                self.website = data["website"] as? String ?? ""
                if let urlString = data["profileImageURL"] as? String {
                    self.profileImageURL = URL(string: urlString)
                }
            }
        }
    }
    
    func loadVacancies() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        vacancyViewModel.loadEmployerVacancies(employerId: uid)
    }
}


struct VacancyCard: View {
    let vacancy: Vacancy
    @State private var showRanking = false
    @State private var showEditVacancy = false
    @State private var showDeleteConfirmation = false
    @EnvironmentObject var vacancyViewModel: VacancyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vacancy.jobTitle)
                    .font(.headline)
                
                Spacer()
                
               
                Text(vacancy.status == "active" ? "Active".localized() : "Inactive".localized())
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vacancy.status == "active" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(vacancy.status == "active" ? .green : .red)
                    .cornerRadius(10)
            }
            
            HStack {
                Image(systemName: "briefcase")
                Text((vacancy.jobType).localized())
                Spacer()
                Image(systemName: "calendar")
                Text(DateFormatter.localizedFormatter(dateStyle: .long).string(from:vacancy.deadlineDate))
            }
            .foregroundColor(.secondary)
            .font(.caption)
            
            Text(vacancy.salaryRange)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            Divider()
                .padding(.vertical, 4)
            
          
            HStack(spacing: 16) {
                
                Button(action: {
                    showRanking = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                        Text("\(vacancy.applicants.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
               
                Button(action: {
                    showEditVacancy = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit".localized())
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                
                Menu {
                    if vacancy.status == "active" {
                        Button(action: {
                            vacancyViewModel.deactivateVacancy(vacancyId: vacancy.id) { success in
                                if success {
                                   
                                    if let index = vacancyViewModel.vacancies.firstIndex(where: { $0.id == vacancy.id }) {
                                        vacancyViewModel.vacancies[index].status = "inactive"
                                    }
                                }
                            }
                        }) {
                            Label("Deactivate".localized(), systemImage: "pause.circle")
                        }
                    } else {
                        Button(action: {
                            vacancyViewModel.activateVacancy(vacancyId: vacancy.id) { success in
                                if success {
                                    
                                    if let index = vacancyViewModel.vacancies.firstIndex(where: { $0.id == vacancy.id }) {
                                        vacancyViewModel.vacancies[index].status = "active"
                                    }
                                }
                            }
                        }) {
                            Label("Activate".localized(), systemImage: "play.circle")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete".localized(), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showRanking) {
            TopsisRankingView(vacancyId: vacancy.id)
        }
        .sheet(isPresented: $showEditVacancy) {
            
            CreateJobVacancyView(vacancyId: vacancy.id)
                .onDisappear {
                    
                    vacancyViewModel.loadEmployerVacancies(employerId: Auth.auth().currentUser?.uid ?? "")
                }
        }
        .alert("Delete Vacancy".localized(), isPresented: $showDeleteConfirmation) {
            Button("Cancel".localized(), role: .cancel) {}
            Button("Delete".localized(), role: .destructive) {
                vacancyViewModel.deleteVacancy(vacancyId: vacancy.id) { _ in
                    
                }
            }
        } message: {
            Text("Are you sure you want to delete this vacancy? This action cannot be undone.".localized())
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
