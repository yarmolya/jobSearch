import Foundation

class JobFieldViewModel: ObservableObject {
    @Published var categories: [JobCategory] = []

    func loadFromJSON() {
        guard let url = Bundle.main.url(forResource: "JobFields", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([JobCategory].self, from: data)
        else {
            print("❌ Failed to load JobFields.json")
            return
        }

        self.categories = decoded
        print("Loaded categories: \(categories)")
    }
}
