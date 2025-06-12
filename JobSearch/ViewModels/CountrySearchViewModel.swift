import Foundation
import Combine

class CountrySearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var predictions: [Prediction] = []  
    
    private var cancellables = Set<AnyCancellable>()
    private let sessionToken = UUID().uuidString
    private let apiKey = "AIzaSyCtSMq9TdnxkIkpq9y1rlhim6L0LzOQmlY"
    
    private var language: String {
        LanguageManager.shared.selectedLanguage
    }
    
    var suggestions: [String] {
        predictions.map { $0.description }  
    }
    
    init() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.fetchCountries(matching: text)
            }
            .store(in: &cancellables)
    }
    
    private func fetchCountries(matching query: String) {
        guard !query.isEmpty else {
            predictions = []
            return
        }
        
        let input = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(input)&types=(regions)&key=\(apiKey)&sessiontoken=\(sessionToken)&language=\(language)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: GooglePlacesResponse.self, decoder: JSONDecoder())
            .map { $0.predictions }
            .replaceError(with: [])
            .receive(on: RunLoop.main)
            .assign(to: &$predictions)
    }
    
    func clearSuggestions() {
        predictions = []
    }

}



struct GooglePlacesResponseUnique: Decodable {
    let predictions: [PredictionUnique]
}

struct PredictionUnique: Decodable {
    let description: String
}

