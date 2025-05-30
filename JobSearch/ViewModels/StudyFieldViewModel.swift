import Foundation

class StudyFieldViewModel: ObservableObject {
    @Published var categories: [StudyCategory] = []
    
    func loadFromJSON() {
        guard let url = Bundle.main.url(forResource: "StudyFields", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([StudyCategory].self, from: data)
        else {
            print("❌ Failed to load StudyFields.json")
            return
        }
        
        self.categories = decoded
    }
}
