//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import MapKit
import ThreemaMacros

@MainActor
final class LocationViewModel: ObservableObject {
    
    // MARK: - Domain type
    
    struct PointOfInterest: Identifiable, Equatable {
        let id = UUID()
        let name: String?
        let latitude: Double
        let longitude: Double
        let accuracy: Double?

        init(name: String?, latitude: Double, longitude: Double, accuracy: Double?) {
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.accuracy = accuracy
        }
        
        var clLocationCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    // MARK: - State
    
    @Published var pointOfInterest: PointOfInterest?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - Public properties
    
    lazy var canOpenGoogleMaps: Bool = UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!)
    
    // MARK: - Strings & Images

    let navigationTitle = #localize("location_view_title")
    let closeButtonText = #localize("close")
    let showInGoogleMapsButtonText = #localize("show_in_google_maps")
    let showInMapsButtonText = #localize("show_in_maps")
    let calculateRouteButtonText = #localize("calculate_route")
    let mapStyleStandardText = #localize("location_view_map_standard")
    let mapStyleHybridText = #localize("location_view_map_hybrid")
    let mapStyleSatelliteText = #localize("location_view_map_satellite")
    let centerMapPinAccessibilityLabel = #localize("location_view_map_center_on_pin")
    
    let shareImageName = "square.and.arrow.up"
    let centerMapPinImageName = "mappin.and.ellipse"
    let mapImageName = "map"
    
    // MARK: - Private properties
    
    private let objectID: NSManagedObjectID
    private lazy var entityFetcher = BusinessInjector.ui.entityManager.entityFetcher
    private lazy var identityStore = BusinessInjector.ui.myIdentityStore
    private lazy var locationManager = LocationManager { [weak self] status in
        self?.authorizationStatus = status
    }
    
    // MARK: - Lifecycle
    
    init(objectID: NSManagedObjectID) {
        self.objectID = objectID
    }
    
    // MARK: - Public actions
    
    func load() {
        guard let entity = entityFetcher.existingObject(with: objectID) as? LocationMessageEntity else {
            return
        }
        
        pointOfInterest = PointOfInterest(
            name: poiName(for: entity),
            latitude: entity.latitude.doubleValue,
            longitude: entity.longitude.doubleValue,
            accuracy: entity.accuracy?.doubleValue ?? nil
        )
    }
    
    func checkPermission() {
        locationManager.checkPermission()
    }
    
    // MARK: Share actions
    
    func showInGoogleMaps() {
        guard let poi = pointOfInterest else {
            return
        }
        
        let coordinate = poi.clLocationCoordinate
        let url = URL(string: "comgooglemaps://?q=\(coordinate.latitude),\(coordinate.longitude)")!
        UIApplication.shared.open(url)
    }

    func showInMaps() {
        guard let poi = pointOfInterest else {
            return
        }
        
        let coordinate = poi.clLocationCoordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = poi.name
        mapItem.openInMaps()
    }

    func calculateRoute() {
        guard let poi = pointOfInterest else {
            return
        }
        
        let coordinate = poi.clLocationCoordinate
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = poi.name
        MKMapItem.openMaps(with: [MKMapItem.forCurrentLocation(), destination], launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
        ])
    }
    
    // MARK: - Helpers
    
    private func poiName(for entity: LocationMessageEntity) -> String? {
        if let name = entity.poiName, !name.isEmpty {
            name
        }
        else if entity.isOwn.boolValue {
            identityStore.pushFromName ?? identityStore.identity
        }
        else if let sender = entity.sender {
            sender.displayName
        }
        else {
            entity.conversation.contact?.displayName
        }
    }
}
