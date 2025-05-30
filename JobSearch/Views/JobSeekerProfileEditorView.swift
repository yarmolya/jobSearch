import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

struct JobSeekerProfileEditorView: View {
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String
    let bio: String
    
    @State private var profileImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var navigateToHome = false
    @State private var isLoading = false
    @State private var photoURL: String?
    @State private var editablePhoneNumber: String = ""
    @State private var editableBio: String = ""
    @State private var imageWasChanged = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile photo
                    if isLoading {
                        ProgressView()
                            .frame(width: 120, height: 120)
                    } else if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                            .padding(.top, 20)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    }

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("Upload profile photo".localized())
                            .foregroundColor(.blue)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                self.profileImage = image
                                self.imageWasChanged = true
                                print("✅ Photo successfully loaded in Image Picker.")
                            }
                        }
                    }

                    Group {
                        TextField("name".localized(), text: .constant(firstName))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        TextField("surname".localized(), text: .constant(lastName))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        TextField("email".localized(), text: .constant(email))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        TextField("Phone number".localized(), text: $editablePhoneNumber)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)

                        TextField("About yourself".localized(), text: $editableBio)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("done".localized())
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isSaving)
                }
                .padding()
            }
            .navigationTitle("Profile editor".localized())
            .navigationDestination(isPresented: $navigateToHome) {
                JobSeekerHomeView() // next step
            }
            .onAppear {
                editablePhoneNumber = phoneNumber
                editableBio = bio
                loadProfileData()
            }
        }
    }
    
    private func loadProfileData() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No UID found")
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("job_seekers").document(uid).getDocument { document, error in
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
            
            editablePhoneNumber = data["phoneNumber"] as? String ?? ""
            editableBio = data["bio"] as? String ?? ""
                        
            
            // Load profile photo if exists
            if let photoURLString = data["photoURL"] as? String {
                photoURL = photoURLString
                loadImageFromURL(photoURLString)
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
            print("❌ No UID found")
            return
        }
        
        isSaving = true
        
        let db = Firestore.firestore()
            var userData: [String: Any] = [
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "phoneNumber": editablePhoneNumber,
                "bio": editableBio,
                "lastUpdated": FieldValue.serverTimestamp()
            ]
        
        // If we have a new image to upload
        if imageWasChanged, let image = profileImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let ref = Storage.storage().reference().child("user_pfp/\(uid).jpg")
                        ref.putData(imageData) { metadata, error in
                            if let error = error {
                                print("❌ Error uploading photo: \(error.localizedDescription)")
                                isSaving = false
                                return
                            }

                            ref.downloadURL { url, error in
                                if let url = url {
                                    userData["photoURL"] = url.absoluteString
                                }

                                self.updateProfileData(db: db, uid: uid, userData: userData)
                            }
                        }
        } else if let photoURL = photoURL {
            // Keep existing photo
            userData["photoURL"] = photoURL
            self.updateProfileData(db: db, uid: uid, userData: userData)
        } else {
            // No photo
            self.updateProfileData(db: db, uid: uid, userData: userData)
        }
    }
    
    private func updateProfileData(db: Firestore, uid: String, userData: [String: Any]) {
        db.collection("job_seekers").document(uid).setData(userData, merge: true) { error in
            isSaving = false
            if let error = error {
                print("❌ Error saving profile: \(error.localizedDescription)")
            } else {
                print("✅ Profile saved successfully")
                navigateToHome = true
            }
        }
    }
}
