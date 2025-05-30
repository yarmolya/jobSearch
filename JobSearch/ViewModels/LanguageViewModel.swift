import Foundation

class LanguageViewModel: ObservableObject {
    @Published var languages: [Language] = []

    func loadFromJSON() {
        guard let url = Bundle.main.url(forResource: "Languages", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Language].self, from: data)
        else {
            print("❌ Failed to load JobFields.json")
            return
        }

        self.languages = decoded
    }
}



