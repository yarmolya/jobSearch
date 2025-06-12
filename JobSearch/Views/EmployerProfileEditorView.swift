import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import FirebaseStorage

struct EmployerProfileEditorView: View {
    @State private var companyName = ""
    @State private var contactPerson = ""
    @State private var description = ""
    @State private var website = ""
    @State private var profileImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @State private var errorMessage = ""
    @State private var photoURL: String?
    @State private var imageWasChanged = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Spacer()
                    
                 
                    VStack(spacing: 24) {
                       
                        VStack(spacing: 8) {
                            Text("Edit company profile".localized())
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                        }
                        
                       
                        VStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .frame(width: 120, height: 120)
                            } else if let profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            } else {
                                Image(systemName: "building.2.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("Upload company logo".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .onChange(of: selectedItem) { _, newItem in
                                if let newItem = newItem {
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = UIImage(data: data) {
                                            self.profileImage = image
                                            self.imageWasChanged = true
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        
                     
                        VStack(spacing: 16) {
                            CustomTextField(
                                title: "Company name".localized(),
                                text: $companyName,
                                systemImage: "building"
                            )
                            
                            CustomTextField(
                                title: "contact person".localized(),
                                text: $contactPerson,
                                systemImage: "person"
                            )
                            
                            CustomTextEditor(
                                title: "company description".localized(),
                                text: $description,
                                systemImage: "text.alignleft"
                            )
                            
                            CustomTextField(
                                title: "Website".localized(),
                                text: $website,
                                systemImage: "globe",
                                keyboardType: .URL
                            )
                            
                            if !errorMessage.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(errorMessage.localized())
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                                .transition(.opacity)
                            }
                        }
                        
                       
                        Button(action: saveProfile) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save".localized())
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 400)
                    
                    Spacer()
                }
                .padding(.vertical, 20)
            }
            .animation(.easeInOut, value: errorMessage.isEmpty)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel".localized()) {
                        dismiss()
                    }
                }
            }
            .alert("Profile updated".localized(), isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Your company profile updated".localized())
            }
            .onAppear {
                loadProfileData()
            }
        }
    }
    
    private func loadProfileData() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated for profile loading.")
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("employers").document(uid).getDocument { document, error in
            isLoading = false
            
            if let error = error {
                print("❌ Error loading profile: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                print("⚠️ No profile data found - will create new")
                return
            }
            
            let data = document.data() ?? [:]
            
            companyName = data["companyName"] as? String ?? ""
            contactPerson = data["contactPerson"] as? String ?? ""
            description = data["description"] as? String ?? ""
            website = data["website"] as? String ?? ""
            
           
            if let profileImageURLString = data["profileImageURL"] as? String {
                photoURL = profileImageURLString
                loadImageFromURL(profileImageURLString)
            }
        }
    }
    
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Error loading profile image: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("❌ Invalid image data")
                return
            }
            
            DispatchQueue.main.async {
                self.profileImage = image
            }
        }.resume()
    }
    
    func saveProfile() {
            guard let uid = Auth.auth().currentUser?.uid else {
                print("❌ User not authenticated!")
                return
            }
            
            isLoading = true
            
            let db = Firestore.firestore()
            let storage = Storage.storage()

            let dataToSave: [String: Any] = [
                "companyName": companyName,
                "contactPerson": contactPerson,
                "description": description,
                "website": website
            ]

        
            if imageWasChanged, let image = profileImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let ref = storage.reference().child("employer_pfp/\(uid).jpg")

                ref.putData(imageData) { metadata, error in
                    if let error = error {
                        print("❌ Error uploading photo: \(error.localizedDescription)")
                        isLoading = false
                        return
                    }

                    ref.downloadURL { url, error in
                        if let error = error {
                            print("❌ Error getting URL for photo: \(error.localizedDescription)")
                            isLoading = false
                            return
                        }

                        guard let url = url else {
                            print("❌ Failed to get URL.")
                            isLoading = false
                            return
                        }

                        var updatedData = dataToSave
                        updatedData["profileImageURL"] = url.absoluteString

                        db.collection("employers").document(uid).setData(updatedData, merge: true) { err in
                            isLoading = false
                            if let err = err {
                                print("❌ Error saving data: \(err.localizedDescription)")
                            } else {
                                showSuccessAlert = true
                            }
                        }
                    }
                }
            } else if let photoURL = photoURL {
               
                var updatedData = dataToSave
                updatedData["profileImageURL"] = photoURL
                
                db.collection("employers").document(uid).setData(updatedData, merge: true) { err in
                    isLoading = false
                    if let err = err {
                        print("❌ Error saving data with existing photo: \(err.localizedDescription)")
                    } else {
                        showSuccessAlert = true
                    }
                }
            } else {
               
                db.collection("employers").document(uid).setData(dataToSave, merge: true) { err in
                    isLoading = false
                    if let err = err {
                        print("❌ Error saving data without photo: \(err.localizedDescription)")
                    } else {
                        showSuccessAlert = true
                    }
                }
            }
        }
    }


struct CustomTextEditor: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            TextEditor(text: $text)
                .frame(height: 100)
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
