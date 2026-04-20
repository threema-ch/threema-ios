final class LocationManager: NSObject {
    
    // MARK: - Properties
    
    private let locationManager: CLLocationManager
    private let onAuthorizationChanged: (CLAuthorizationStatus) -> Void
    
    // MARK: - Lifecycle
    
    init(onAuthorizationChanged: @escaping (CLAuthorizationStatus) -> Void) {
        let locationManager = CLLocationManager()
        
        self.locationManager = locationManager
        self.onAuthorizationChanged = onAuthorizationChanged
        
        super.init()
        self.locationManager.delegate = self
        self.onAuthorizationChanged(locationManager.authorizationStatus)
    }
    
    // MARK: - Public action
    
    func checkPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor [weak self] in
            self?.onAuthorizationChanged(status)
        }
    }
}
