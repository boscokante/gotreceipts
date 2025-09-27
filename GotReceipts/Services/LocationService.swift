import Foundation
import CoreLocation

// A simple wrapper around CLLocationManager to get a single location update.
class LocationService: NSObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((CLLocation?) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    // New function to convert coordinates to a city/state string.
    func reverseGeocode(location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                print("Reverse geocoding failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            // Combine city and state for a user-friendly format.
            let locationName = [placemark.locality, placemark.administrativeArea]
                .compactMap { $0 } // Remove nils
                .joined(separator: ", ") // e.g., "Berkeley, CA"
            
            completion(locationName)
        }
    }

    // The main function to call when we want to get the user's location.
    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        self.locationCompletion = completion
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // If we haven't asked for permission yet, ask for it.
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // If we already have permission, start getting the location.
            locationManager.requestLocation()
        default:
            // If permission was denied or restricted, complete with nil.
            print("Location permission was denied or restricted.")
            completion(nil)
        }
    }

    // MARK: - CLLocationManagerDelegate Methods

    // This delegate method is called when the user responds to the permission pop-up.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            // Now that we have permission, request the location.
            locationManager.requestLocation()
        } else {
            // If they denied permission, we can't get a location.
            locationCompletion?(nil)
            locationCompletion = nil
        }
    }

    // This delegate method is called when the location is successfully retrieved.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Return the most recent location and stop listening.
        locationCompletion?(locations.last)
        locationCompletion = nil
    }

    // This delegate method is called if there's an error getting the location.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
        locationCompletion?(nil)
        locationCompletion = nil
    }
}