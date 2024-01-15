//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

// MARK: - ThreemaPOI

public struct ThreemaPOI: Decodable {
    let id: Int
    let name: String
    let lat: Double
    let lon: Double
    let dist: Int
    let category: POICategory
    let subcategory: String
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: CodingKeys.id)
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.lat = try container.decode(Double.self, forKey: CodingKeys.lat)
        self.lon = try container.decode(Double.self, forKey: CodingKeys.lon)
        self.dist = try container.decode(Int.self, forKey: CodingKeys.dist)
        
        // The POIs category gets sent as key in JSON and changes for each received POI, therefore decoding is not
        // straightforward
        let receivedCategory = container.allKeys.first(where: { key in
            POICategory.allCases.contains { $0.rawValue == key.stringValue }
        }) ?? .other
        
        self.category = POICategory.allCases.first(where: { receivedCategory.stringValue == $0.rawValue }) ?? .other
        self.subcategory = try container.decodeIfPresent(String.self, forKey: receivedCategory) ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case lat
        case lon
        case dist
        
        // Categories
        case amenity
        case tourism
        case sport
        case leisure
        case shop
        case natural
        case publicTransport = "public_transport"
        case aerialway
        case aeroway
        case highway
        case place
        case marked
        case current
        case other
    }
}

// MARK: - PointOfInterest

public class PointOfInterest: Equatable, Hashable {
        
    public var type: POIType
    public var name: String
    public var location: CLLocation
    public var distance: POIDistance
    public var category: POICategory
    public var detailCategory: String
    public var address: String?
    public var image: UIImage
    
    // MARK: - Lifecycle
    
    public init(receivedPOI: ThreemaPOI) {
        self.type = .threemaPOI(id: receivedPOI.id)
        self.name = receivedPOI.name
        self.location = CLLocation(latitude: receivedPOI.lat, longitude: receivedPOI.lon)
        self.distance = .distance(receivedPOI.dist)
        self.category = receivedPOI.category
        self.detailCategory = receivedPOI.subcategory
        self.image = PointOfInterest.icon(for: receivedPOI.subcategory)
    }
    
    public init(
        type: POIType,
        name: String,
        location: CLLocation,
        distance: Int,
        category: POICategory,
        detailCategory: String
    ) {
        self.type = type
        self.name = name
        self.location = location
        self.distance = .distance(distance)
        self.category = category
        self.detailCategory = detailCategory
        self.image = PointOfInterest.icon(for: detailCategory)
    }
    
    public init(
        type: POIType,
        name: String,
        location: CLLocation,
        distance: POIDistance,
        category: POICategory,
        detailCategory: String
    ) {
        self.type = type
        self.name = name
        self.location = location
        self.distance = distance
        self.category = category
        self.detailCategory = detailCategory
        self.image = PointOfInterest.icon(for: detailCategory)
    }
    
    // MARK: - Protocol Functions

    public static func == (lhs: PointOfInterest, rhs: PointOfInterest) -> Bool {
        lhs.type == rhs.type
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
    }
}

// MARK: - Annotation

public class POIAnnotation: MKPointAnnotation {
    
    public var type: POIType?
    
    init(for poi: PointOfInterest) {
        super.init()
        
        self.type = poi.type
        self.coordinate = poi.location.coordinate
        self.title = poi.name
    }
}

// MARK: - Enums

public enum POIType: Hashable, Equatable {
    case currentLocationPOI
    case markedLocationPOI
    case threemaPOI(id: Int)
}

public enum POIDistance: Hashable, Equatable {
    case notAvailable
    case notSet
    case distance(Int)
}

public enum POICategory: String, CaseIterable {
    // Given by Backend
    case amenity
    case tourism
    case sport
    case leisure
    case shop
    case natural
    case publicTransport
    case aerialway
    case aeroway
    case highway
    case place
    
    // Additional for Handling
    case marked
    case current
    case other
}

extension PointOfInterest {
    private static let symbolDictionary = [
        
        // Own poi-subcategories
        "current": "location.fill",
        "marked": "mappin.and.ellipse",
        
        // IOS 13
        "department_store": "bag.fill",
        "car": "car.fill",
        "cinema": "film",
        "conveniecne": "bag.fill",
        "gallery": "photo.fill.on.rectangle.fill",
        "gift": "gift.fill",
        "hotel": "bed.double.fill",
        "information": "info.circle.fill",
        "mall": "bag.fill",
        "optician": "eyeglasses",
        "post_office": "envelope.fill",
        "recylcing": "arrow.3.trianglepath",
        "hairdresser": "scissors",
        "station": "tram.fill",
        "supermarket": "cart.fill",
        
        // IOS 14
        "atm": "banknote.fill",
        "bank": "banknote.fill",
        "beauty": "comb.fill",
        "bicycle": "bicycle",
        "books": "books.vertical.fill",
        "bus_stop": "bus.fill",
        "car_sharing": "car.2.fill",
        "dentist": "cross.case.fill",
        "doctors": "cross.case.fill",
        "garden": "leaf.fill",
        "library": "books.vertical.fill",
        "mobile_phone": "simcard.2.fill",
        "pharmacy": "pills.fill",
        "playground": "die.face.5.fill",
        "platform": "bus.fill",
        "school": "graduationcap.fill",
        "stop_position": "bus.fill",
        "ticket": "ticket.fill",
        "viewpoint": "binoculars.fill",
        
        // IOS 15
        "boat_renting": "ferry.fill",
        "boat_sharing": "ferry.fill",
        "cafe": "fork.knife",
        "coffe": "fork.knife",
        "clothes": "tshirt.fill",
        "ferry_terminal": "ferry.fill",
        "parking": "parkingsign",
        "pub": "fork.knife",
        "restaurant": "fork.knife",
        "theatre": "theatermasks.fill",
        "travel_agency": "globe.europe.africa.fill",
        "fast_food": "takeoutbag.and.cup.and.straw.fill",
        "fuel": "fuelpump.fill",
        "yachting": "ferry.fill",
    ]
    
    /// SF Symbol representing the subcategory, or pin image on iOS 12 or no image is set for subcategory
    /// - Parameter subCategory: Subcategory of a POI
    /// - Returns: SF Symbol for provided subcategory
    static func icon(for subCategory: String) -> UIImage {
        if let value = symbolDictionary[subCategory],
           let image = UIImage(systemName: value) {
            return image
        }
        
        if let image = UIImage(systemName: "mappin") {
            return image
        }
        return UIImage(named: "mappin_regular.L")!
    }
}
