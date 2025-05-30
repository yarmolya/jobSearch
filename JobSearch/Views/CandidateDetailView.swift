import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import WebKit

enum ExperienceFormatter {
    static func formatExperience(_ years: Double) -> String {
        if years < 1 {
            let months = Int(years * 12)
            let format = months == 1 ? "%d \("month".localized())" : "%d \("months".localized())"
            return String(format: format, months)
        } else if years == 1 {
            return "1 \("year".localized())"
        } else {
            if years.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%d \("years".localized())", Int(years))
            } else {
                return String(format: "%.1f \("years".localized())", years)
            }
        }
    }
}


struct CandidateDetailView: View {
    let candidate: TopsisCandidate
    @Environment(\.dismiss) private var dismiss
    @State private var profileImageURL: URL?
    @State private var showingCVPreview = false
    @State private var cvURL: String?
    @State private var contactInfo: (phone: String?, email: String?, bio: String?) = (nil, nil, nil)
    
    var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header with candidate info
                        VStack(alignment: .center, spacing: 10) {
                            // Profile Picture
                            if let profileImageURL = profileImageURL {
                                AsyncImage(url: profileImageURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } placeholder: {
                                    ProgressView()
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                            }
                            
                            Text("\(candidate.firstName) \(candidate.lastName)")
                                .font(.headline)
                            
                            Text(candidate.location)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Text((candidate.educationLevel).localized())
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(20)
                                
                                if candidate.experience > 0 {
                                    Text(ExperienceFormatter.formatExperience(candidate.experience))
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundColor(.green)
                                        .cornerRadius(20)
                                }
                            }
                            
                            if let bio = contactInfo.bio, !bio.isEmpty {
                                VStack {
                                    Text("About".localized())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 5)
                            }
                            
                            // CV Button if available
                            if let cvURL = cvURL {
                                Button(action: {
                                    self.showingCVPreview = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                        Text("View CV".localized())
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 5)
                                .sheet(isPresented: $showingCVPreview) {
                                    if let url = URL(string: cvURL) {
                                        NavigationStack {
                                            WebView(url: url)
                                                .toolbar {
                                                    ToolbarItem(placement: .navigationBarTrailing) {
                                                        Button("Done".localized()) {
                                                            showingCVPreview = false
                                                        }
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                            
                            // Match score
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(candidate.absoluteScore))
                                    .stroke(scoreColor(score: candidate.absoluteScore), lineWidth: 8)
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack {
                                    Text(String(format: "%.0f%%", candidate.absoluteScore * 100))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("Match".localized())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Score breakdown
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Score Breakdown".localized())
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            scoreBarView(title: "Education".localized(), score: candidate.educationScore, color: .blue)
                            scoreBarView(title: "Experience".localized(), score: candidate.experienceScore, color: .green)
                            scoreBarView(title: "Field match".localized(), score: candidate.fieldMatchScore, color: .orange)
                            scoreBarView(title: "Skills".localized(), score: candidate.skillsScore, color: .purple)
                            scoreBarView(title: "Location".localized(), score: candidate.locationScore, color: .pink)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Contact Information Block
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contact Information".localized())
                                .font(.headline)
                            
                            if let phone = contactInfo.phone, !phone.isEmpty {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(.blue)
                                    Text(phone)
                                        .font(.subheadline)
                                }
                            }
                            
                            if let email = contactInfo.email, !email.isEmpty {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.blue)
                                    Text(email)
                                        .font(.subheadline)
                                }
                            }
                            
                            if contactInfo.phone == nil && contactInfo.email == nil {
                                Text("No contact information available".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding()
                }
                .navigationTitle("Candidate Details".localized())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close".localized()) {
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    fetchProfilePicture()
                    fetchCVURL()
                    fetchContactInfo()
                }
            }
        }
    
    private func fetchProfilePicture() {
        let storageRef = Storage.storage().reference()
        // Changed from profile_pictures to user_pfp to match security rules
        let profilePictureRef = storageRef.child("user_pfp/\(candidate.id).jpg")
        
        profilePictureRef.downloadURL { url, error in
            if let error = error {
                print("Error fetching profile picture: \(error.localizedDescription)")
            } else {
                self.profileImageURL = url
            }
        }
    }
    
    private func fetchCVURL() {
        let db = Firestore.firestore()
        db.collection("job_seekers").document(candidate.id).getDocument { document, error in
            if let document = document, document.exists {
                // Store the document ID for direct resume fetching if needed
                if let resumeFilename = document.data()?["resumeFilename"] as? String {
                    // Construct a proper resume filename matching the security rules pattern
                    let formattedFilename = "\(candidate.id)_\(resumeFilename)"
                    let storageRef = Storage.storage().reference()
                    let resumeRef = storageRef.child("resumes/\(formattedFilename)")
                    
                    resumeRef.downloadURL { url, error in
                        if let url = url {
                            self.cvURL = url.absoluteString
                        } else if let error = error {
                            print("Error fetching resume URL: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Fallback to the stored URL if available
                    self.cvURL = document.data()?["resumeURL"] as? String
                }
            }
        }
    }
    private func fetchContactInfo() {
           let db = Firestore.firestore()
           db.collection("job_seekers").document(candidate.id).getDocument { document, error in
               if let document = document, document.exists {
                   let data = document.data()
                   contactInfo.phone = data?["phoneNumber"] as? String
                   contactInfo.email = data?["email"] as? String
                   contactInfo.bio = data?["bio"] as? String
               }
           }
       }
    
    private func scoreBarView(title: String, score: Double, color: Color) -> some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", score * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .opacity(0.2)
                            .foregroundColor(color)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .frame(width: geometry.size.width * CGFloat(score), height: 8)
                            .foregroundColor(color)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
        }
        
        private func scoreColor(score: Double) -> Color {
            if score >= 0.8 {
                return .green
            } else if score >= 0.6 {
                return .blue
            } else if score >= 0.4 {
                return .orange
            } else {
                return .red
            }
        }
        
    



}

// WebView for displaying PDF CV
struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}
