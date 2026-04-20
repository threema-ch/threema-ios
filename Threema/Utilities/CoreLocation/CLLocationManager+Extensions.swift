import CoreLocation

extension CLLocationManager {
    var locationGranted: Bool {
        [CLAuthorizationStatus.authorizedAlways, .authorizedWhenInUse].contains(authorizationStatus)
    }
}
