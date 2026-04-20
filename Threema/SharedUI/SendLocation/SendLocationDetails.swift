enum SendLocationDetails {
    
    enum State {
        case map
        case search
    }
    
    enum Section {
        case standardPOI
        case threemaPOI
    }
    
    enum ZoomDistance: CLLocationDistance {
        case veryFar = 5000
        case far = 1000
        case medium = 400
        case close = 100
    }
}
