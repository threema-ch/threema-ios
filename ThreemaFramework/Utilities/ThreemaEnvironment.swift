//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
}
