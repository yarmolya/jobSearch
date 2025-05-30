import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct EmployerRegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var companyName = ""
    @State private var contactPerson = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isRegistered = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // Centered content
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("employer registration".localized())
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(spacing: 16) {
                        RegisterTextField(
                            title: "email".localized(),
                            text: $email,
                            systemImage: "envelope",
                            keyboardType: .emailAddress
                        )
                        
                        RegisterSecureField(
                            title: "password".localized(),
                            text: $password,
                            systemImage: "lock"
                        )
                        
                        RegisterTextField(
                            title: "company name".localized(),
                            text: $companyName,
                            systemImage: "building.2"
                        )
                        
                        RegisterTextField(
                            title: "contact person".localized(),
                            text: $contactPerson,
                            systemImage: "person.fill"
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
                        
                        if isRegistered {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Registration success".localized())
                            }
                            .foregroundColor(.green)
                            .font(.subheadline)
                            .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Sign up button
                    Button(action: registerEmployer) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("sign up".localized())
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(RegisterPrimaryButtonStyle())
                    .disabled(isLoading)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 400)
                
                Spacer()
            }
            .animation(.easeInOut, value: errorMessage.isEmpty)
            .animation(.easeInOut, value: isRegistered)
            .navigationDestination(isPresented: $isRegistered) {
                EmployerProfileEditorView()
            }
        }
    }
    
    func registerEmployer() {
        errorMessage = ""
        isLoading = true
        
        // Validate required fields
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Email is required.".localized()
            isLoading = false
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Password is required.".localized()
            isLoading = false
            return
        }
        
        guard !companyName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Company name is required.".localized()
            isLoading = false
            return
        }
        
        guard !contactPerson.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Contact person is required.".localized()
            isLoading = false
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error as NSError? {
                errorMessage = translateAuthError(error)
                isLoading = false
                return
            }
            
            guard let uid = result?.user.uid else {
                errorMessage = "Failed to get user ID.".localized()
                isLoading = false
                return
            }
            
            let db = Firestore.firestore()
            let employerData: [String: Any] = [
                "uid": uid,
                "email": email,
                "companyName": companyName,
                "contactPerson": contactPerson,
                "createdAt": Timestamp()
            ]
            
            db.collection("employers").document(uid).setData(employerData) { error in
                isLoading = false
                if let error = error {
                    errorMessage = String(format: "Error saving data:".localized(), error.localizedDescription)
                } else {
                    print("✅ Employer registered.")
                    isRegistered = true
                }
            }
        }
    }
}
