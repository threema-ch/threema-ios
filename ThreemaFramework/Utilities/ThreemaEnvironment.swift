//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import ThreemaProtocols

public class ThreemaEnvironment: NSObject {
    @objc public enum EnvironmentType: Int, CustomStringConvertible {
        case appStore
        case testFlight
        case xcode
        
        public var shortDescription: String {
            switch self {
            case .appStore:
                ""
            case .testFlight:
                "-T"
            case .xcode:
                "-X"
            }
        }
        
        public var description: String {
            switch self {
            case .appStore:
                "appstore"
            case .testFlight:
                "testflight"
            case .xcode:
                "xcode"
            }
        }
    }

    @objc public static func env() -> EnvironmentType {
        #if DEBUG
            return .xcode
        #endif
        
        // TestFLight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        }
        
        return .appStore
    }
    
    // MARK: - Feature flags
    
    // MARK: Forward security
    
    /// Does this client support Forward Security?
    @objc public static var supportsForwardSecurity: Bool {
        let bi = BusinessInjector()
        if bi.userSettings.enableMultiDevice {
            return false
        }
        
        return true
    }
    
    /// Max FS supported by this client. Mostly useful for manual testing of upgrades.
    static let fsMaxVersion = CspE2eFs_Version.v12
    
    #if DEBUG
        // This exists purely for unit tests.
        static var fsVersion: CspE2eFs_VersionRange = {
            var range = CspE2eFs_VersionRange()
            range.min = UInt32(CspE2eFs_Version.v10.rawValue)
            range.max = UInt32(fsMaxVersion.rawValue)

            return range
        }()
    #else
        static var fsVersion: CspE2eFs_VersionRange {
            var range = CspE2eFs_VersionRange()
            range.min = UInt32(CspE2eFs_Version.v10.rawValue)
            range.max = UInt32(fsMaxVersion.rawValue)
        
            return range
        }
    #endif
    
    static var fsDebugStatusMessages: Bool {
        if ProcessInfoHelper.isRunningForScreenshots {
            return false
        }
        #if DEBUG
            return true
        #else
            if ThreemaApp.current == .green || ThreemaApp.current == .blue {
                return true
            }
            return false
        #endif
    }
    
    // MARK: Distribution list
    
    @objc public static var distributionListsActive: Bool {
        if ProcessInfoHelper.isRunningForScreenshots {
            return false
        }
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    // MARK: Delete & edit messages
    
    @objc public static var deleteEditMessage: Bool {
        if ProcessInfoHelper.isRunningForScreenshots {
            return false
        }
 
        return true
    }
    
    // MARK: Multi-device
    
    public static var allowMultipleLinkedDevices: Bool {
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return false
        }
        
        return true
    }
    
    // MARK: CallKit
    
    @objc public static func supportsCallKit() -> Bool {
        let locale = Locale.current
        var countryCode = ""
        
        if #available(iOS 16, *) {
            if let value = locale.region?.identifier {
                countryCode = value
            }
        }
        else {
            if let value = locale.regionCode {
                countryCode = value
            }
        }

        if countryCode.contains("CN") || countryCode.contains("CHN") {
            return false
        }
        return true
    }
}
