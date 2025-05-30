import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthService: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userRole: UserRole = .unknown
    @Published var userId: String? = nil
    @Published var isLoading: Bool = false
    
    enum UserRole {
        case jobSeeker
        case employer
        case unknown
    }

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()

    init() {
        setupAuthListener()
    }

    deinit {
        removeAuthListener()
    }

    private func setupAuthListener() {
        // Remove any existing listener first
        removeAuthListener()
        
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            
            self.isLoading = true
            
            if let user = user {
                self.userId = user.uid
                self.isLoggedIn = true
                self.checkUserRole(uid: user.uid)
            } else {
                self.clearUserData()
            }
            
            self.isLoading = false
        }
    }
    
    private func removeAuthListener() {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authHandle = nil
        }
    }
    
    private func clearUserData() {
        DispatchQueue.main.async {
            self.userId = nil
            self.isLoggedIn = false
            self.userRole = .unknown
        }
    }

    private func checkUserRole(uid: String) {
        // Create a dispatch group to handle both checks
        let group = DispatchGroup()
        var isJobSeeker = false
        var isEmployer = false
        
        group.enter()
        db.collection("job_seekers").document(uid).getDocument { snapshot, error in
            defer { group.leave() }
            isJobSeeker = snapshot?.exists == true
        }
        
        group.enter()
        db.collection("employers").document(uid).getDocument { snapshot, error in
            defer { group.leave() }
            isEmployer = snapshot?.exists == true
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if isJobSeeker {
                self.userRole = .jobSeeker
            } else if isEmployer {
                self.userRole = .employer
            } else {
                self.userRole = .unknown
                print("User role not found for uid: \(uid)")
                
                // If user has no role, consider signing them out
                self.signOut()
            }
        }
    }

    func signOut() {
        isLoading = true
        do {
            try Auth.auth().signOut()
            clearUserData()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    // Add this function to refresh the auth state
    func refreshAuthState() {
        if let user = Auth.auth().currentUser {
            user.reload { [weak self] error in
                if let error = error {
                    print("Error reloading user: \(error.localizedDescription)")
                    self?.signOut()
                } else {
                    self?.setupAuthListener()
                }
            }
        } else {
            clearUserData()
        }
    }
}
