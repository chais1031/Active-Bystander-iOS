import Foundation
import CoreLocation

struct MLocation: Codable {
    let latitude: Double
    let longitude: Double
    let username: String
}

extension CLLocationCoordinate2D {
    func toMLocation(username: String) -> MLocation {
        return MLocation(latitude: latitude, longitude: longitude, username: username)
    }
}

extension MLocation {
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
