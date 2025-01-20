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

import Foundation

public enum Platform: Int, Sendable {
    case unspecified = 0
    case android = 1
    case ios = 2
    case desktop = 3
    case web = 4

    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .android
        case 2: self = .ios
        case 3: self = .desktop
        case 4: self = .web
        default: self = .unspecified
        }
    }

    public var rawValue: Int {
        switch self {
        case .unspecified: 0
        case .android: 1
        case .ios: 2
        case .desktop: 3
        case .web: 4
        }
    }
    
    public var systemSymbolName: String {
        switch self {
        case .ios:
            "iphone"
        case .android:
            if #available(iOS 17.0, *) {
                "smartphone"
            }
            else {
                "iphone"
            }
        case .desktop, .web, .unspecified:
            "desktopcomputer"
        }
    }
}

public struct DeviceInfo: Sendable {
    public let deviceID: UInt64
    public let label: String
    public let lastLoginAt: Date
    public let badge: String?
    public let platform: Platform
    public let platformDetails: String?
    
    public init(
        deviceID: UInt64,
        label: String,
        lastLoginAt: Date,
        badge: String?,
        platform: Platform,
        platformDetails: String?
    ) {
        self.deviceID = deviceID
        self.label = label
        self.lastLoginAt = lastLoginAt
        self.badge = badge
        self.platform = platform
        self.platformDetails = platformDetails
    }
}

// MARK: - Equatable

extension DeviceInfo: Equatable {
    // intentionally left blank: the Swift compiler will synthesize an
    // implementation of func == that will return true iff all properties
    // are equal
}

// MARK: - Identifiable

extension DeviceInfo: Identifiable {
    public typealias ID = UInt64

    public var id: UInt64 {
        deviceID
    }
}
