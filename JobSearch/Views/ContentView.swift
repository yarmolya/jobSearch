import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // Centered content
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("welcome".localized())
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    // Role selection buttons
                    VStack(spacing: 16) {
                        NavigationLink(destination: JobSeekerRegisterView()) {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("looking for a job".localized())
                            }
                            .roleSelectionButtonStyle(backgroundColor: .blue)
                        }
                        
                        NavigationLink(destination: EmployerRegisterView()) {
                            HStack {
                                Image(systemName: "briefcase.fill")
                                Text("employer".localized())
                            }
                            .roleSelectionButtonStyle(backgroundColor: .green)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 400)
                
                Spacer()
            }
            
        }
    }
}

// Button Style Extension
extension View {
    func roleSelectionButtonStyle(backgroundColor: Color) -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [backgroundColor, backgroundColor.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: backgroundColor.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

