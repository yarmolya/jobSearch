import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var navigateToJobSeeker = false
    @State private var navigateToEmployer = false
    
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // Centered content
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Log in to your account".localized())
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Welcome back! Please enter your details".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Form fields
                    VStack(spacing: 16) {
                        CustomTextField(
                            title: "email".localized(),
                            text: $email,
                            systemImage: "envelope",
                            keyboardType: .emailAddress
                        )
                        
                        CustomSecureField(
                            title: "password".localized(),
                            text: $password,
                            systemImage: "lock"
                        )
                        
                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMessage)
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                            .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Login button
                    Button(action: loginUser) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Log in".localized())
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 400)
                
                Spacer()
                
                // Sign up link
                NavigationLink {
                    ContentView()
                } label: {
                    HStack {
                        Text("Don't have an account?".localized())
                            .foregroundColor(.secondary)
                        Text("Sign up!".localized())
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .padding(.bottom, 40)
                }
            }
            .animation(.easeInOut, value: errorMessage.isEmpty)
        }
    }
    
    func loginUser() {
        errorMessage = ""
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                isLoading = false
                errorMessage = "Login error: \(error.localizedDescription)".localized()
                return
            }
            
            guard let uid = result?.user.uid else {
                isLoading = false
                errorMessage = "Failed to get user UID.".localized()
                return
            }
            
            let db = Firestore.firestore()
            let group = DispatchGroup()
            var isJobSeeker = false
            var isEmployer = false
            
            group.enter()
            db.collection("job_seekers").document(uid).getDocument { snapshot, error in
                if let document = snapshot, document.exists {
                    isJobSeeker = true
                }
                group.leave()
            }
            
            group.enter()
            db.collection("employers").document(uid).getDocument { snapshot, error in
                if let document = snapshot, document.exists {
                    isEmployer = true
                }
                group.leave()
            }
            
            group.notify(queue: .main) {
                isLoading = false
                if isJobSeeker {
                    navigateToJobSeeker = true
                } else if isEmployer {
                    navigateToEmployer = true
                } else {
                    errorMessage = "Profile not found. It may be incomplete or deleted.".localized()
                }
            }
        }
    }
}

// MARK: - Custom Components

struct CustomTextField: View {
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

struct CustomSecureField: View {
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

struct PrimaryButtonStyle: ButtonStyle {
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
