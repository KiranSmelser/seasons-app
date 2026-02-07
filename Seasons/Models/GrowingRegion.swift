import Foundation
import CoreLocation

enum GrowingRegion: String, Codable, CaseIterable, Identifiable {
    case northeast
    case southeast
    case midwest
    case greatPlains
    case southwest
    case pacificNorthwest
    case california

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .northeast: "Northeast"
        case .southeast: "Southeast"
        case .midwest: "Midwest"
        case .greatPlains: "Great Plains"
        case .southwest: "Southwest"
        case .pacificNorthwest: "Pacific Northwest"
        case .california: "California"
        }
    }

    /// Maps a coordinate to the closest US growing region using simplified bounding boxes.
    static func from(coordinate: CLLocationCoordinate2D) -> GrowingRegion {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // California
        if lat >= 32.5 && lat <= 42.0 && lon >= -124.5 && lon <= -114.0 {
            return .california
        }
        // Pacific Northwest (WA, OR)
        if lat >= 42.0 && lat <= 49.0 && lon >= -124.8 && lon <= -116.5 {
            return .pacificNorthwest
        }
        // Southwest (AZ, NM, NV, UT)
        if lat >= 31.0 && lat <= 42.0 && lon >= -120.0 && lon <= -103.0 {
            return .southwest
        }
        // Great Plains (TX, OK, KS, NE, SD, ND, MT, WY, CO)
        if lat >= 26.0 && lat <= 49.0 && lon >= -111.0 && lon <= -95.0 {
            return .greatPlains
        }
        // Southeast (south of ~37°N, east of ~95°W)
        if lat < 37.0 && lon >= -95.0 {
            return .southeast
        }
        // Midwest (north of ~37°N, between ~95°W and ~80°W)
        if lat >= 37.0 && lon >= -95.0 && lon < -80.0 {
            return .midwest
        }
        // Northeast (everything else in the eastern US)
        return .northeast
    }
}
