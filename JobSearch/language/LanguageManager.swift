import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "AppLanguage")
            Bundle.setLanguage(selectedLanguage)
        }
    }

    private init() {
        selectedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        Bundle.setLanguage(selectedLanguage)
    }
}




