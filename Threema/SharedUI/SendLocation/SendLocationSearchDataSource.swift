//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaMacros

final class SendLocationSearchDataSource: UITableViewDiffableDataSource<SendLocationDetails.Section, PointOfInterest> {
    
    // MARK: - Properties

    var pointsOfInterest = [PointOfInterest]()

    private weak var sendLocationViewController: SendLocationViewController?
    private weak var searchTableView: UITableView?
    private let mapsServerInfo: MapsServerInfo?
        
    private static var locationGranted: Bool {
        CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager
            .authorizationStatus() == .authorizedWhenInUse
    }
    
    private static let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.numberFormatter.roundingMode = .up
        return formatter
    }()
    
    private let cellProvider: SendLocationSearchDataSource.CellProvider = { tableView, indexPath, poi in
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)

        cell.textLabel?.text = String.localizedStringWithFormat(
            #localize("poi_search_prefix"),
            poi.name
        )
        
        return cell
    }
    
    // MARK: - Init
    
    init(
        sendLocationViewController: SendLocationViewController,
        tableView: UITableView,
        mapsServerInfo: MapsServerInfo?
    ) {
        self.sendLocationViewController = sendLocationViewController
        self.searchTableView = tableView
        self.mapsServerInfo = mapsServerInfo
        super.init(tableView: tableView, cellProvider: cellProvider)
        configureDataSource(with: tableView)
    }
    
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<SendLocationDetails.Section, PointOfInterest>.CellProvider
    ) {
        fatalError("Just use init(tableView:).")
    }
    
    // MARK: - Configure content
    
    func configureDataSource(with tableView: UITableView) {
        guard let sendLocationVC = sendLocationViewController else {
            return
        }
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")

        var snapshot = NSDiffableDataSourceSnapshot<SendLocationDetails.Section, PointOfInterest>()
        
        // Standard POI Section
        snapshot.appendSections([.standardPOI])
        
        // Only add CurrentLocation and MarkedPoi if selectable
        if SendLocationSearchDataSource.locationGranted {
            snapshot.appendItems([sendLocationVC.currentLocationPOI], toSection: .standardPOI)
        }
        if sendLocationVC.markedLocationPOI.location.coordinate.latitude != 0.1 {
            snapshot.appendItems([sendLocationVC.markedLocationPOI], toSection: .standardPOI)
        }
        
        // Threema POI Section
        snapshot.appendSections([.threemaPOI])
        snapshot.appendItems(pointsOfInterest, toSection: .threemaPOI)
        
        apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - Change Items
    
    /// Removes all fetched ThreemaPOIs
    func removePOIs() {
        var snapshot = snapshot()
        snapshot.deleteItems(pointsOfInterest)
        
        apply(snapshot, animatingDifferences: false)
    }
    
    /// Checks if currentLocation or markedLocationCell need to be added
    func checkStandardPOI() {
        guard let sendLocationVC = sendLocationViewController else {
            return
        }
        
        var snapshot = snapshot()
        
        if !snapshot.itemIdentifiers.contains(sendLocationVC.currentLocationPOI),
           SendLocationSearchDataSource.locationGranted {
            snapshot.appendItems([sendLocationVC.currentLocationPOI], toSection: .standardPOI)
        }
        if snapshot.indexOfItem(sendLocationVC.markedLocationPOI) == nil,
           sendLocationVC.markedLocationPOI.location.coordinate.latitude != 0.1 {
            snapshot.appendItems([sendLocationVC.markedLocationPOI], toSection: .standardPOI)
        }
        apply(snapshot)
    }
    
    /// Refreshes all elements of a section
    /// - Parameter section: SendLocationDetails.Section to be refreshed
    func refresh(section: SendLocationDetails.Section) {
        var localSnapshot = snapshot()
        
        localSnapshot.reloadSections([section])
        apply(localSnapshot, animatingDifferences: true)
    }
}

// MARK: - ThreemaPOI API

extension SendLocationSearchDataSource {
    
    /// Fetches POIs for a given Term
    /// - Parameter term: Search-Term
    func requestPOIsFor(term: String) {
        
        if TargetManager.isOnPrem, mapsServerInfo == nil {
            return
        }
        
        // Don't fetch if POI are disabled in privacy settings
        guard UserSettings.shared().enablePoi,
              let baseString = mapsServerInfo?.poiNamesURL else {
            return
        }
        
        var urlString = ""
        
        if SendLocationSearchDataSource.locationGranted {
            if let location = CLLocationManager().location {
                urlString = baseString + String(location.coordinate.latitude) + "/" +
                    String(location.coordinate.longitude) + "/" + term + "/"
            }
        }
        else {
            // Zurich coordinates
            urlString = baseString + "47.366869/8.543220/" + term + "/"
        }
        
        guard let urlstr = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: urlstr) else {
            DDLogError("POI URL could not be created")
            return
        }
        
        HTTPClient().downloadData(url: url, contentType: .json) { data, _, error in
            do {
                guard let data else {
                    return
                }
                // Decode Data
                let decoder = JSONDecoder()
                var threemaPOIs = try decoder.decode([ThreemaPOI].self, from: data)
                threemaPOIs.sort(by: { $0.dist < $1.dist })
                
                // Remove old POIs
                var localSnapshot = self.snapshot()
                localSnapshot.deleteItems(self.pointsOfInterest)
                
                // Add new POIs and apply
                self.pointsOfInterest = threemaPOIs.map { PointOfInterest(receivedPOI: $0) }
                localSnapshot.appendItems(self.pointsOfInterest, toSection: .threemaPOI)
                DispatchQueue.main.async {
                    self.apply(localSnapshot)
                }
            }
            catch {
                DDLogError("Error during fetching or decoding POIs: \(error.localizedDescription)")
            }
        }
    }
}
