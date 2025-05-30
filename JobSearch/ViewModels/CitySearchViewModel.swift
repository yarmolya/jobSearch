import Foundation
import Combine
import CoreLocation

class CitySearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var predictions: [Prediction] = []
    @Published var countryCode: String = ""

    private var cancellables = Set<AnyCancellable>()
    private let sessionToken = UUID().uuidString
    private let apiKey = "AIzaSyCtSMq9TdnxkIkpq9y1rlhim6L0LzOQmlY"

    private var language: String {
        LanguageManager.shared.selectedLanguage
    }

    var suggestions: [String] {
        predictions.map { $0.description }
    }
    
    // Add a method to clear predictions which will in turn clear suggestions
    func clearSuggestions() {
        predictions = []
    }

    init() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.fetchCities(matching: text)
            }
            .store(in: &cancellables)
    }

    private func fetchCities(matching query: String) {
        guard !query.isEmpty else {
            predictions = []
            return
        }

        let input = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(input)&types=(cities)&key=\(apiKey)&sessiontoken=\(sessionToken)&language=\(language)"

        if !countryCode.isEmpty {
            urlString += "&components=country:\(countryCode.lowercased())"
        }

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: GooglePlacesResponse.self, decoder: JSONDecoder())
            .map { $0.predictions }
            .replaceError(with: [])
            .receive(on: RunLoop.main)
            .assign(to: &$predictions)
    }

    func fetchCoordinates(for placeID: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let urlString = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(placeID)&fields=geometry&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let response = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)
                if let location = response.result.geometry?.location {
                    let coordinate = CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
                    completion(coordinate)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    func fetchLocalizedName(for placeID: String, completion: @escaping (String?) -> Void) {
        let urlString = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(placeID)&fields=name,formatted_address&language=\(language)&key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let response = try JSONDecoder().decode(PlaceDetailsResponseWithName.self, from: data)
                let name = response.result.name ?? response.result.formatted_address
                completion(name)
            } catch {
                completion(nil)
            }
        }.resume()

    }

}



struct GooglePlacesResponse: Decodable {
    let predictions: [Prediction]
}

struct Prediction: Decodable, Hashable {
    let description: String
    let place_id: String
}

struct PlaceDetailsResponse: Decodable {
    let result: PlaceDetails
}

struct PlaceDetails: Decodable {
    let geometry: Geometry?
}

struct Geometry: Decodable {
    let location: Location
}

struct Location: Decodable {
    let lat: Double
    let lng: Double
}

struct PlaceDetailsResponseWithName: Decodable {
    let result: PlaceDetailsWithName
}

struct PlaceDetailsWithName: Decodable {
    let name: String?
    let formatted_address: String?
}
