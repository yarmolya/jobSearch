import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var selectedLanguage: String? = nil
    @State private var goNext = false
    @State private var refreshView = false
    
    let buttonWidth: CGFloat = 280
    let flagSize: CGFloat = 32
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
               
                VStack(spacing: 24) {
                  
                    VStack(spacing: 8) {
                        Text("choose_language".localized())
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                   
                    VStack(spacing: 16) {
                        languageButton(title: "ukrainian".localized(), code: "uk", flagName: "uk")
                        languageButton(title: "english".localized(), code: "en", flagName: "en")
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
               
                if selectedLanguage != nil {
                    Button(action: {
                        withAnimation(.spring()) {
                            goNext = true
                        }
                    }) {
                        HStack {
                            Text("continue".localized())
                                .font(.headline)
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 40)
                }
            }
            .id(refreshView)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: selectedLanguage)
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $goNext) {
                NavigationStack {
                    LoginView()
                }
            }
        }
    }
    
    @ViewBuilder
    private func languageButton(title: String, code: String, flagName: String) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedLanguage = code
                languageManager.selectedLanguage = code
                refreshView.toggle()
            }
        }) {
            HStack(spacing: 16) {
                Image(flagName)
                    .resizable()
                    .frame(width: flagSize, height: flagSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .shadow(radius: 2)
                
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(selectedLanguage == code ? .white : .primary)
                
                Spacer()
                
                if selectedLanguage == code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(width: buttonWidth)
            .background(
                Group {
                    if selectedLanguage == code {
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                     startPoint: .leading,
                                     endPoint: .trailing)
                    } else {
                        Color(.systemBackground)
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedLanguage == code ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: selectedLanguage == code ? Color.blue.opacity(0.2) : Color.clear,
                    radius: 8, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

