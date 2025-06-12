import SwiftUI
import FirebaseCore

@main
struct JobSearchApp: App {
    
    
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack{
                RootView()
            }
        }
    }
}

struct RootView: View {
    @StateObject private var authService = AuthService()
    
    var body: some View {
        Group {
            if authService.isLoggedIn {
                if authService.userRole == .jobSeeker {
                    JobSeekerHomeView()
                } else if authService.userRole == .employer {
                    EmployerHomeView()
                }
            } else {
                LanguageSelectionView()
            }
        }
        .environmentObject(authService)
    }
}
