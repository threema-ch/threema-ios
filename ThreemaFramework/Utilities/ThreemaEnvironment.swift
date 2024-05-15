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

@objc public class ThreemaEnvironment: NSObject {
    @objc public enum EnvironmentType: Int {
        case appStore
        case testFlight
        case xcode
        
        public func description() -> String {
            switch self {
            case .appStore:
                return ""
            case .testFlight:
                return "-T"
            case .xcode:
                return "-X"
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
        #if DEBUG
            return true
        #else
            if ThreemaApp.current == .green || ThreemaApp.current == .blue {
                return true
            }
            return false
        #endif
    }
    
    // TODO: (IOS-4362) Remove
    @objc public static var fsEnableV12: Bool {
        true
    }
    
    @objc static var distributionListsActive: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    @objc public static var deleteEditMessage: Bool {
        #if DEBUG
            true
        #else
            if ThreemaApp.current == .green || ThreemaApp.current == .blue {
                return true
            }

            return false
        #endif
    }

    // MARK: - CallKit
    
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
