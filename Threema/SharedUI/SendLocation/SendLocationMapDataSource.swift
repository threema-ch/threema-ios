//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import MapKit

protocol SendLocationDataSourceMapDelegate: AnyObject {
    
    func poisDidChange(pois: [PointOfInterest])
    func currentLocationPOIDidChange(select: Bool)
    func didReceiveInitialLocation()
}

final class SendLocationMapDataSource: UITableViewDiffableDataSource<SendLocationDetails.Section, PointOfInterest> {
    
    // MARK: - Properties
    
    var pointsOfInterest = [PointOfInterest]()
    
    weak var delegate: SendLocationDataSourceMapDelegate?
    
    private weak var sendLocationViewController: SendLocationViewController?
    private weak var mapTableView: UITableView?
    private weak var mapView: MKMapView?
    private let locationManager = CLLocationManager()
    
    private var initialFetchCompleted = false
    private lazy var postalAddressFormatter: CNPostalAddressFormatter = {
        let postalAddressFormatter = CNPostalAddressFormatter()
        postalAddressFormatter.style = .mailingAddress
        return postalAddressFormatter
    }()
    
    // MARK: - Init
    
    init(
        sendLocationViewController: SendLocationViewController,
        tableView: UITableView,
        mapView: MKMapView
    ) {
        self.sendLocationViewController = sendLocationViewController
        self.mapTableView = tableView
        self.mapView = mapView
        
        super.init(tableView: tableView, cellProvider: cellProvider)
        
        configureLocationManager()
        configureDataSource(with: tableView)
    }
    
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<SendLocationDetails.Section, PointOfInterest>.CellProvider
    ) {
        fatalError("Just use init(tableView:).")
    }
    
    private let cellProvider: SendLocationMapDataSource.CellProvider = { tableView, indexPath, poi in
        
        let poiCell: POICell = tableView.dequeueCell(for: indexPath)
        poiCell.poi = poi
        return poiCell
    }
    
    // MARK: - Configure DiffableDataSource
    
    /// Configures DiffableDataSource
    func configureDataSource(with tableView: UITableView) {
        
        guard let sendLocationVC = sendLocationViewController else {
            return
        }
        
        tableView.registerCell(POICell.self)
        
        var snapshot = NSDiffableDataSourceSnapshot<SendLocationDetails.Section, PointOfInterest>()
        
        // Standard POI Section
        snapshot.appendSections([.standardPOI])
        snapshot.appendItems(
            [sendLocationVC.currentLocationPOI, sendLocationVC.markedLocationPOI]
        )
        
        // Threema POI Section
        if UserSettings.shared().enablePoi {
            snapshot.appendSections([.threemaPOI])
        }
        
        apply(snapshot, animatingDifferences: true)
    }
    
    // MARK: - Change Items
    
    /// Refreshes single POI and applies new snapshot
    /// - Parameter poi: PointOfInterest to refresh
    func refresh(poi: PointOfInterest) {
        let selected = mapTableView?.indexPathForSelectedRow
        var localSnapshot = snapshot()
        
        localSnapshot.reconfigureItems([poi])
        apply(localSnapshot)
        mapTableView?.selectRow(at: selected, animated: false, scrollPosition: .top)
    }
    
    private func refresh(section: SendLocationDetails.Section) {
        var localSnapshot = snapshot()
        
        localSnapshot.reloadSections([section])
        apply(localSnapshot, animatingDifferences: false)
    }
    
    /// Load address of POI and assign it to it
    /// - Parameters:
    ///   - poi: POI of address to be fetched for
    ///   - completion: called after Address is assigned
    func addAddress(to poi: PointOfInterest, completion: @escaping () -> Void) {
        guard poi.address == nil else {
            completion()
            return
        }
        
        fetchAddress(for: poi.location) { address in
            poi.address = address
            completion()
        }
    }
    
    func updateDistanceLabel(of pois: [PointOfInterest], from location: CLLocation) {
        
        guard let sendLocationVC = sendLocationViewController else {
            return
        }
        
        // Used to track changes in .threemaPOI section
        var refreshThreemaPOIs = false
        
        for poi in pois {
            switch poi.type {
            case .currentLocationPOI:
                // Only update if set
                if sendLocationViewController?.currentLocationPOI.location.coordinate.latitude == 0.0 {
                    continue
                }
                sendLocationViewController?.currentLocationPOI
                    .distance = .distance(Int(sendLocationVC.currentLocationPOI.location.distance(from: location)))
                refresh(poi: sendLocationVC.currentLocationPOI)
                
            case .markedLocationPOI:
                // Only update if set
                if sendLocationViewController?.markedLocationPOI.location.coordinate.latitude == 0.1 {
                    continue
                }
                sendLocationViewController?.markedLocationPOI
                    .distance = .distance(Int(sendLocationVC.markedLocationPOI.location.distance(from: location)))
                refresh(poi: sendLocationVC.markedLocationPOI)
                
            default:
                poi.distance = .distance(Int(poi.location.distance(from: location)))
                refreshThreemaPOIs = true
            }
        }
        
        // Refresh if section has changes
        if refreshThreemaPOIs {
            refresh(section: .threemaPOI)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SendLocationMapDataSource: CLLocationManagerDelegate {
    
    func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 50 // triggers locationManager only every 50m
        checkLocationAccess()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAccess()
    }
    
    /// Checks location access and sets up views according to authorizationStatus
    private func checkLocationAccess() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            
            // Only request location once if imprecise location is enabled
            if #available(iOS 14.0, *) {
                if CLLocationManager().accuracyAuthorization == .reducedAccuracy {
                    locationManager.startUpdatingLocation()
                    locationManager.stopUpdatingLocation()
                    return
                }
            }
            
            locationManager.startUpdatingLocation()
            sendLocationViewController?.currentLocationPOI.distance = .distance(0)
        case .notDetermined:
            // Request Access
            locationManager.requestWhenInUseAuthorization()
        default:
            // Access Denied
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let sendLocationVC = sendLocationViewController else {
            return
        }
        
        // Center map on user if imprecise location is enabled
        if #available(iOS 14.0, *) {
            if CLLocationManager().accuracyAuthorization == .reducedAccuracy {
                sendLocationVC.centerMap(on: location.coordinate, zoom: .veryFar, animated: true)
                return
            }
        }
        
        // Update CurrentLocationPOI
        sendLocationVC.currentLocationPOI.location = location
        fetchAddress(for: location) { address in
            self.sendLocationViewController?.currentLocationPOI.address = address
            self.refresh(poi: sendLocationVC.currentLocationPOI)
            self.delegate?.currentLocationPOIDidChange(select: false)
        }
        
        // Update distance labels
        updateDistanceLabel(of: pointsOfInterest, from: location)
        updateDistanceLabel(of: [sendLocationVC.markedLocationPOI], from: location)
        
        // Load POIS around user location on first update
        if !initialFetchCompleted {
            initialFetchCompleted = true
            delegate?.didReceiveInitialLocation()
            requestPOIsAround(location: location, radius: 10000) {
                sendLocationVC.selectPOI(poi: sendLocationVC.currentLocationPOI)
            }
        }
    }
    
    func distanceToCurrentLocation(location: CLLocation) -> Int {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager
            .authorizationStatus() == .authorizedAlways {
            guard let userLocation = locationManager.location else {
                return 0
            }
            return Int(userLocation.distance(from: location))
        }
        return 0
    }
}

// MARK: - ThreemaPOI API

extension SendLocationMapDataSource {
    
    /// Fetches up to 30 POIs in a defined radius around a location
    /// - Parameters:
    ///   - location: Location to load POIs around
    ///   - radius: max radius for POIs in meters
    ///   - completion: called after POIS are loaded
    func requestPOIsAround(location: CLLocation, radius: Int, completion: (() -> Void)? = nil) {
        
        // Don't fetch if POI are disabled in privacy settings or URL can not be divided into components
        guard UserSettings.shared().enablePoi,
              var components = URLComponents(
                  string: BundleUtil
                      .object(forInfoDictionaryKey: "ThreemaPOIAroundURL") as! String
              ) else {
            return
        }
        components.path = "/around/" + String(location.coordinate.latitude) + "/" +
            String(location.coordinate.longitude) +
            "/\(radius)/"
        
        guard let url = components.url else {
            DDLogError("POI URL could not be created")
            return
        }
        
        HTTPClient().downloadData(url: url, contentType: .json) { data, _, error in
            do {
                guard let data = data else {
                    DDLogError("Did not receive POI: \(error)")
                    return
                }
                // Decode Data
                let decoder = JSONDecoder()
                var threemaPOIs = try decoder.decode([ThreemaPOI].self, from: data)
                threemaPOIs.sort(by: { $0.dist < $1.dist })
                
                // Remove old POIs from Datasource
                var localSnapshot = self.snapshot()
                localSnapshot.deleteSections([.threemaPOI])
                localSnapshot.appendSections([.threemaPOI])
                
                // Add new POIs to Datasource
                self.pointsOfInterest = threemaPOIs.map { PointOfInterest(receivedPOI: $0) }
                localSnapshot.appendItems(self.pointsOfInterest, toSection: .threemaPOI)
                
                DispatchQueue.main.async {
                    
                    // Apply snapshot and inform Delegate
                    self.apply(localSnapshot, animatingDifferences: true) {
                        self.delegate?.poisDidChange(pois: self.pointsOfInterest)
                    }
                    
                    // Change distances of ThreemaPOI relative to current location if available
                    if CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager
                        .authorizationStatus() == .authorizedWhenInUse, let location = CLLocationManager().location {
                        self.updateDistanceLabel(of: self.pointsOfInterest, from: location)
                    }
                    completion?()
                }
            }
            catch {
                DDLogError("Error during fetching or decoding POIs: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Address Fetching
    
    /// Fetches an Address of a given Location and creates a localized Address-String
    /// - Parameters:
    ///   - location: Location of Address to be fetched
    ///   - completion: Closure that returns the Address-String
    private func fetchAddress(for location: CLLocation, completion: @escaping (String?) -> Void) {
        
        // Don't fetch address if POI are disabled in privacy settings
        guard UserSettings.shared().enablePoi else {
            completion(nil)
            return
        }
        
        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale.current) { placemarks, _ in
            guard let placemark = placemarks?.first, let postalAddress = placemark.postalAddress else {
                completion(nil)
                return
            }
            // Format address and return it
            completion(self.postalAddressFormatter.string(from: postalAddress))
        }
    }
}
