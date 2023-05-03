//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import CoreLocation
import Foundation
import MapKit
import UIKit

class SendLocationViewController: ThemedViewController {
    
    // MARK: - Properties
    
    // Special POIs (These are placed here since both of the datasources need to access them, possible point for improving in future)
    var currentLocationPOI = PointOfInterest(
        type: .currentLocationPOI,
        name: BundleUtil.localizedString(forKey: "poi_current_location"),
        location: CLLocation(latitude: 0.0, longitude: 0.0),
        distance: .notAvailable,
        category: .current,
        detailCategory: "current"
    )
    
    var markedLocationPOI = PointOfInterest(
        type: .markedLocationPOI,
        name: BundleUtil.localizedString(forKey: "poi_marked_location"),
        location: CLLocation(latitude: 0.1, longitude: 0.1),
        distance: .notSet,
        category: .marked,
        detailCategory: "marked"
    )
    
    private let conversation: Conversation
    
    // DiffableDataSource
    private lazy var mapDataSource = SendLocationMapDataSource(
        sendLocationViewController: self,
        tableView: mapTableView,
        mapView: mapView
    )
    private lazy var searchDataSource = SendLocationSearchDataSource(
        sendLocationViewController: self,
        tableView: searchTableView
    )
    
    // Buttons
    private lazy var sendButton = UIBarButtonItem(
        title: BundleUtil.localizedString(forKey: "send"),
        style: .done,
        target: self,
        action: #selector(sendButtonAction)
    )
    private lazy var cancelButton = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(cancelButtonAction)
    )
    
    private var refreshControl: UIRefreshControl {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        return refreshControl
    }
    
    // Views
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [mapView, mapTableView, searchTableView])
        stackView.axis = .vertical
        stackView.spacing = 0.5 // Used to "fake" hairline between views
        stackView.backgroundColor = Colors.hairLine
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        return stackView
    }()
    
    private lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.tintColor = .primary
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.showsUserLocation = false
        
        // Hides Apples POIs
        mapView.pointOfInterestFilter = .excludingAll
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(addMarkedPOI(gesture:)))
        mapView.addGestureRecognizer(longPressGesture)
        
        mapView.accessibilityElementsHidden = true
        return mapView
    }()
    
    private var mapTableView: UITableView = {
        let tableViewMap = UITableView()
        tableViewMap.translatesAutoresizingMaskIntoConstraints = false
        tableViewMap.tableFooterView = UIView(frame: .zero) // Removes empty placeholder cells
        tableViewMap.rowHeight = UITableView.automaticDimension
        return tableViewMap
    }()
    
    private var searchTableView: UITableView = {
        let tableViewSearch = UITableView()
        tableViewSearch.translatesAutoresizingMaskIntoConstraints = false
        tableViewSearch.tableFooterView = UIView(frame: .zero) // Removes empty placeholder cells
        
        return tableViewSearch
    }()
    
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = BundleUtil.localizedString(forKey: "poi_search_POI")
        
        return searchController
    }()
    
    private var state: SendLocationDetails.State = .search {
        didSet {
            if oldValue == state {
                return
            }
            
            if oldValue == .map {
                mapView.isHidden = true
                mapTableView.isHidden = true
                searchTableView.isHidden = false
                stackView.setNeedsLayout()
            }
            else if oldValue == .search {
                mapView.isHidden = false
                mapTableView.isHidden = false
                searchTableView.isHidden = true
                stackView.setNeedsLayout()
            }
        }
    }
    
    private var lastSearchTerm = ""
    
    // MARK: - Lifecycle
    
    @objc init(conversation: Conversation) {
        self.conversation = conversation
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        // NavBar
        navigationItem.title = BundleUtil.localizedString(forKey: "send_location")
        navigationItem.largeTitleDisplayMode = .never
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = sendButton
        
        // Delegates
        mapTableView.delegate = self
        searchTableView.delegate = self
        mapView.delegate = self
        searchController.delegate = self
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        mapDataSource.delegate = self
        
        // Configure Views & Constraints
        configureStackView()
        
        // Don't show SearchBar if POI are disabled in privacy settings
        if UserSettings.shared().enablePoi {
            navigationItem.searchController = searchController
            mapTableView.refreshControl = refreshControl
        }
        
        isModalInPresentation = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // UI
        updateColors()
        sendButton.isEnabled = false
    }
    
    override func updateColors() {
        super.updateColors()
        
        stackView.backgroundColor = Colors.hairLine
        
        // Workaround for breaking constraints when updating color when TableView is not yet visible. XCode 12.5.1.
        if mapTableView.visibleSize.width != 0.0 {
            for cell in mapTableView.visibleCells {
                guard let cell = cell as? POICell else {
                    return
                }
                cell.updateColors()
            }
        }
    }
}

// MARK: - SendLocationDataSourceMapDelegate

extension SendLocationViewController: SendLocationDataSourceMapDelegate {
    
    // Called after first time user location is received
    func didReceiveInitialLocation() {
        centerMap(on: currentLocationPOI.location.coordinate, zoom: .close, animated: true)
        
        let annotationCurrentPOI = POIAnnotation(for: currentLocationPOI)
        mapView.addAnnotation(annotationCurrentPOI)
        mapView.selectAnnotation(annotationCurrentPOI, animated: false)
    }
    
    func currentLocationPOIDidChange(select: Bool = true) {
        // Create new Annotation
        let annotation = POIAnnotation(for: currentLocationPOI)
        
        // Replace Old Annotation
        removeAnnotation(for: currentLocationPOI.type)
        mapView.addAnnotation(annotation)
        
        // Select again
        if select {
            mapView.selectAnnotation(annotation, animated: true)
        }
    }
    
    func poisDidChange(pois: [PointOfInterest]) {
        // Remove old Annotations
        removeThreemaPOIAnnotations()
        
        let selectionIndexPath = mapTableView.indexPathForSelectedRow
        
        // Place new Annotations
        for poi in pois {
            let annotation = POIAnnotation(for: poi)
            mapView.addAnnotation(annotation)
        }
        
        // Select current location POI again if it was selected
        if let indexPath = selectionIndexPath,
           indexPath == mapDataSource.indexPath(for: currentLocationPOI) {
            mapTableView.selectRow(at: indexPath, animated: false, scrollPosition: .top)
            mapDataSource.refresh(poi: currentLocationPOI)
        }
    }
}

// MARK: - StackView

extension SendLocationViewController {
    
    /// ConfiguresStackView with all its Properties and its Layout
    private func configureStackView() {

        view.addSubview(stackView)
        state = .map
        
        // Layout
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}

// MARK: - MKMapViewDelegate

extension SendLocationViewController: MKMapViewDelegate {
    
    /// Create custom MKAnnotationView
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        // Skip user location Annotation, we'll add our own
        guard let annotation = annotation as? POIAnnotation else {
            return nil
        }
        var annotationView = mapView
            .dequeueReusableAnnotationView(withIdentifier: "identifier") as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "identifier")
        }
        else {
            annotationView?.annotation = annotation
        }
        
        annotationView?.accessibilityElementsHidden = true
        annotationView?.markerTintColor = .primary
        
        // If Annotation does not belong to fetched POI, it belongs to current- or markedLocation
        guard let poi = mapDataSource.pointsOfInterest.first(where: { annotation.type == $0.type }) else {
            if annotation.type == .currentLocationPOI {
                annotationView?.displayPriority = .required
            }
            else {
                annotationView?.displayPriority = .defaultHigh
            }
            return annotationView
        }
        
        annotationView?.glyphImage = poi.image
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? POIAnnotation else {
            return
        }
        
        // Find Selected POI
        let poi: PointOfInterest
        if annotation.type == .currentLocationPOI {
            // Current Location
            poi = currentLocationPOI
        }
        else if annotation.type == .markedLocationPOI {
            // Marked Location
            poi = markedLocationPOI
        }
        else {
            // One of Other POI
            guard let fetchedPoi = mapDataSource.pointsOfInterest.first(where: { $0.type == annotation.type }) else {
                return
            }
            poi = fetchedPoi
        }
       
        let currentSelectionIndex = mapTableView.indexPathForSelectedRow
        if let index = currentSelectionIndex {
            mapTableView.deselectRow(at: index, animated: true)
        }
        
        mapTableView.selectRow(
            at: mapDataSource.indexPath(for: poi),
            animated: true,
            scrollPosition: .top
        )
        
        mapDataSource.addAddress(to: poi) {
            self.mapDataSource.refresh(poi: poi)
            self.mapTableView.scrollToRow(at: self.mapDataSource.indexPath(for: poi)!, at: .top, animated: true)
        }
        
        updateSendButton()
        
        // Set Center of Map on POI
        centerMap(on: poi.location.coordinate, zoom: .close)
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        if let indexPath = mapTableView.indexPathForSelectedRow {
            mapTableView.deselectRow(at: indexPath, animated: true)
        }
        updateSendButton()
    }
    
    /// Centers Region of Map
    /// - Parameters:
    ///   - location: Location of desired Center
    ///   - zoom: Zoom level
    ///   - animated: Transition animated
    func centerMap(
        on location: CLLocationCoordinate2D,
        zoom: SendLocationDetails.ZoomDistance,
        animated: Bool = true
    ) {
        let region = MKCoordinateRegion(
            center: location,
            latitudinalMeters: zoom.rawValue,
            longitudinalMeters: zoom.rawValue
        )
        mapView.setRegion(region, animated: animated)
    }
    
    /// Adds a Marker to the Map upon long-press Gesture
    /// - Parameter gesture: LongPressGesture
    @objc func addMarkedPOI(gesture: UILongPressGestureRecognizer) {
        
        if gesture.state == .began {
            
            // Translate Touch-Location to Coordinate
            let point = gesture.location(in: mapView)
            let location2D = mapView.convert(point, toCoordinateFrom: mapView)
            let location = CLLocation(latitude: location2D.latitude, longitude: location2D.longitude)
            
            markLocation(location: location)
        }
    }
    
    /// Returns an Annotation for a POI if it exists
    /// - Parameter for: Type of POI
    /// - Returns: POIAnnotation? belonging to POI
    private func getAnnotation(for type: POIType) -> POIAnnotation? {
        let annotations = mapView.annotations.compactMap { $0 as? POIAnnotation }
        let annotation = annotations.first(where: { $0.type == type })
        return annotation
    }
    
    /// Removes all ThreemaPOIAnnotations from MapView
    private func removeThreemaPOIAnnotations() {
        let annotations = mapView.annotations.compactMap { $0 as? POIAnnotation }
        mapView
            .removeAnnotations(annotations.filter { $0.type != .currentLocationPOI && $0.type != .markedLocationPOI })
    }
    
    /// Removes single Annotation
    /// - Parameter for: type of POI
    private func removeAnnotation(for type: POIType) {
        let annotations = mapView.annotations.compactMap { $0 as? POIAnnotation }
        guard let annotation = annotations.first(where: { $0.type == type }) else {
            return
        }
        mapView.removeAnnotation(annotation)
    }
}

// MARK: - UITableViewDelegate

extension SendLocationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Use mapTableView
        if state == .map {
            didSelectMapTableViewCell(tableView: tableView, indexPath: indexPath)
        }
        // Use searchTableView
        else {
            didSelectTableViewSearchCell(tableView: tableView, indexPath: indexPath)
        }
    }
    
    private func didSelectMapTableViewCell(tableView: UITableView, indexPath: IndexPath) {
        
        // No POI in DataSource
        guard let poi = mapDataSource.itemIdentifier(for: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        // CurrentLocation not granted
        if poi.type == .currentLocationPOI, poi.location.coordinate.latitude == 0.0 {
            tableView.deselectRow(at: indexPath, animated: true)
            updateSendButton()
            
            // If access is denied and user taps, show alert to enable access
            if CLLocationManager.authorizationStatus() == .denied {
                showDeniedAlert()
                return
            }
            
            // If precise location is disabled, show alert
            if CLLocationManager().accuracyAuthorization == .reducedAccuracy {
                showAccuracyAlert()
            }
            return
        }
        // No marked Location available
        else if poi.type == .markedLocationPOI, poi.location.coordinate.latitude == 0.1 {
            showDropPinAlert()
            tableView.deselectRow(at: indexPath, animated: true)
            updateSendButton()
            return
        }
        
        // Select Annotation
        guard let annotation = getAnnotation(for: poi.type) else {
            return
        }
        
        mapView.selectAnnotation(annotation, animated: true)
        mapDataSource.refresh(poi: poi)
    }
    
    private func didSelectTableViewSearchCell(tableView: UITableView, indexPath: IndexPath) {
        
        // No POI in DataSource
        guard let poi = searchDataSource.itemIdentifier(for: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        // User selected POI to search around, hide Search and present Map
        state = .map
        searchController.isActive = false
        searchController.searchBar.text = poi.name
        lastSearchTerm = poi.name
        
        // Request points around selected
        mapDataSource.requestPOIsAround(location: poi.location, radius: 10000) {
            
            self.searchDataSource.refresh(section: .standardPOI)
            
            if poi.type == .currentLocationPOI {
                self.currentLocationPOIDidChange(select: true)
            }
            else {
                self.updateMarkedPOI(name: poi.name, location: poi.location)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        if let poi = mapDataSource.itemIdentifier(for: indexPath) {
            mapDataSource.refresh(poi: poi)
        }
        
        updateSendButton()
    }
    
    @objc private func refreshTriggered(refreshControl: UIRefreshControl) {
        
        let location = CLLocation(
            latitude: mapView.centerCoordinate.latitude,
            longitude: mapView.centerCoordinate.longitude
        )
        
        // If current location is center of map simply select it
        if isSameLocation(currentLocationPOI.location, location) {
            selectPOI(poi: currentLocationPOI)
        }
        else {
            // Fetch points around center of map and display them
            mapDataSource.requestPOIsAround(location: location, radius: 10000)
        }
        refreshControl.endRefreshing()
    }
}

// MARK: - UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate

extension SendLocationViewController: UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    
    func didPresentSearchController(_ searchController: UISearchController) {
        // Hide Map and show Search
        state = .search
        
        // Start updating Results
        updateSearchResults(for: searchController)
        
        // Check if standardPOIs need to be added
        searchDataSource.checkStandardPOI()
        
        // Deselect row from previous selection
        if let selected = searchTableView.indexPathForSelectedRow {
            searchTableView.deselectRow(at: selected, animated: false)
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        
        // Prevent search triggering if in map state and if no text entered
        guard let term = searchController.searchBar.text,
              state == .search else {
            return
        }
        
        // API only returns result if term has 3 or more letters
        if term.count >= 3 {
            searchDataSource.requestPOIsFor(term: term)
        }
        else {
            searchDataSource.removePOIs()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Change back to map state
        state = .map
        searchController.searchBar.text = lastSearchTerm
    }
}

// MARK: - Other

extension SendLocationViewController {
    
    /// Dismisses View
    @objc func cancelButtonAction() {
        dismiss(animated: true, completion: nil)
    }
    
    /// Sends selected Location
    @objc func sendButtonAction() {
        
        guard let indexPath = mapTableView.indexPathForSelectedRow,
              let poi = mapDataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        // Do not send poiName if is currentLocation or markedLocation
        var name: String?
        if poi.type != .currentLocationPOI, poi.type != .markedLocationPOI {
            name = poi.name
        }
        
        MessageSender.sendLocation(
            poi.location.coordinate,
            accuracy: poi == currentLocationPOI ? currentLocationPOI.location.horizontalAccuracy : 0.0,
            poiName: name,
            poiAddress: poi.address,
            in: conversation,
            onCompletion: { _ in }
        )
        
        dismiss(animated: true, completion: nil)
    }
    
    private func markLocation(location: CLLocation) {
        // Update MarkedPOI
        updateMarkedPOI(name: BundleUtil.localizedString(forKey: "poi_marked_location"), location: location)
        
        mapDataSource.requestPOIsAround(location: location, radius: 10000) {
            self.selectPOI(poi: self.markedLocationPOI)
        }
    }
    
    /// Enables or Disables the send Button depending on if a selected Cell exists
    private func updateSendButton() {
        if mapTableView.indexPathForSelectedRow != nil {
            sendButton.isEnabled = true
        }
        else {
            sendButton.isEnabled = false
        }
    }
    
    private func updateMarkedPOIAnnotation() {
        // Remove old annotation
        removeAnnotation(for: markedLocationPOI.type)
        
        // Create new annotation
        let annotation = POIAnnotation(for: markedLocationPOI)
        
        // Place new annotation and select it
        mapView.addAnnotation(annotation)
    }
    
    private func updateMarkedPOI(name: String, location: CLLocation) {
        markedLocationPOI.location = location
        markedLocationPOI.address = nil
        markedLocationPOI.distance = .distance(mapDataSource.distanceToCurrentLocation(location: location))
        markedLocationPOI.name = name
        mapDataSource.addAddress(to: markedLocationPOI) {
            self.updateMarkedPOIAnnotation()
            self.selectPOI(poi: self.markedLocationPOI)
            self.mapDataSource.refresh(poi: self.markedLocationPOI)
        }
    }
    
    func selectPOI(poi: PointOfInterest) {
        
        guard let indexPath = mapDataSource.indexPath(for: poi),
              let annotation = getAnnotation(for: poi.type) else {
            return
        }
        
        DispatchQueue.main.async {
            self.mapView.selectAnnotation(annotation, animated: true)
            self.mapTableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
            self.mapDataSource.refresh(poi: poi)
            self.updateSendButton()
        }
    }
    
    private func isSameLocation(_ a: CLLocation, _ b: CLLocation) -> Bool {
        if abs(a.coordinate.latitude - b.coordinate.latitude) < 0.00001,
           abs(a.coordinate.longitude - b.coordinate.longitude) < 0.00001 {
            return true
        }
        return false
    }
    
    /// Shows alert that location access is denied, with option to take the user to the settings-app
    private func showDeniedAlert() {
        UIAlertTemplate.showOpenSettingsAlert(
            owner: self,
            noAccessAlertType: .location
        )
    }
    
    /// Shows alert that precise location is turned off, with option to take the user to the settings-app
    private func showAccuracyAlert() {
        UIAlertTemplate.showOpenSettingsAlert(
            owner: self,
            noAccessAlertType: .preciseLocation
        )
    }
    
    /// Shows alert that instructs how to drop pin
    private func showDropPinAlert() {
        
        UIAlertTemplate.showAlert(
            owner: self,
            title: BundleUtil.localizedString(forKey: "poi_dropped_pin_info_alert_title"),
            message: BundleUtil.localizedString(forKey: "poi_dropped_pin_info_alert_message")
        )
    }
}
