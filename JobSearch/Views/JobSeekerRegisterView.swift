import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct JobSeekerRegisterView: View {
    @State private var name = ""
    @State private var surname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var navigateToProfile = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // Centered content
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Create your account".localized())
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Join our community of job seekers".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Form fields
                    VStack(spacing: 16) {
                        RegisterTextField(
                            title: "name".localized(),
                            text: $name,
                            systemImage: "person"
                        )
                        
                        RegisterTextField(
                            title: "surname".localized(),
                            text: $surname,
                            systemImage: "person"
                        )
                        
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
                    .padding(.vertical, 8)
                    
                    // Sign up button
                    Button(action: registerJobSeeker) {
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
            .navigationDestination(isPresented: $navigateToProfile) {
                JobSeekerProfileEditorView(
                    firstName: name,
                    lastName: surname,
                    email: email,
                    phoneNumber: "",
                    bio: ""
                )
            }
        }
    }
    
    func registerJobSeeker() {
        errorMessage = ""
        isLoading = true
        
        // Validate required fields
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "First name is required.".localized()
            isLoading = false
            return
        }
        
        guard !surname.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Last name is required.".localized()
            isLoading = false
            return
        }
        
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
            let seekerData: [String: Any] = [
                "uid": uid,
                "firstName": name,
                "lastName": surname,
                "email": email,
                "createdAt": Timestamp()
            ]
            
            db.collection("job_seekers").document(uid).setData(seekerData) { error in
                isLoading = false
                if let error = error {
                    errorMessage = "Error saving data: \(error.localizedDescription)"
                } else {
                    print("✅ Job seeker registered.")
                    navigateToProfile = true
                }
            }
        }
    }
    
    }

// Unique component names for this view to avoid redeclaration
struct RegisterTextField: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RegisterSecureField: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
            SecureField(title, text: $text)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RegisterPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

func  translateAuthError(_ error: Error) -> String {
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .invalidEmail:
                return "Invalid email format.".localized()
            case .emailAlreadyInUse:
                return "Email is already in use.".localized()
            case .weakPassword:
                return "Password is too weak. Use at least 6 characters.".localized()
            case .wrongPassword:
                return "Incorrect password.".localized()
            case .userNotFound:
                return "No user found with this email.".localized()
            case .networkError:
                return "Network error. Please check your connection.".localized()
            default:
                return String(format: "Error: %@".localized(), error.localizedDescription)
            }
        }
        return String(format: "Error: %@".localized(), error.localizedDescription)
    }
