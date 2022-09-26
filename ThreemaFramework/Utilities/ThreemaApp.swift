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

import Foundation

public enum ThreemaApp {
    case threema
    case work
    case red
    case workRed
    case onPrem
    
    public static var current: ThreemaApp {
        if LicenseStore.isOnPrem() {
            return .onPrem
        }
        else if LicenseStore.requiresLicenseKey() {
            if isRed {
                return .workRed
            }
            return .work
        }
        if isRed {
            return .red
        }
        
        return .threema
    }
    
    public static var currentName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    }
    
    private static var isRed: Bool {
        let bundle = BundleUtil.mainBundle()
        return bundle?.bundleIdentifier?.contains(".red") ?? false
    }
}

@objc public class ThreemaAppObjc: NSObject {
    @objc public enum ThreemaApp: Int, RawRepresentable {
        case threema
        case work
        case red
        case workRed
        case onPrem
    }
    
    @objc public class func current() -> ThreemaApp {
        if LicenseStore.isOnPrem() {
            return .onPrem
        }
        else if LicenseStore.requiresLicenseKey() {
            if ThreemaAppObjc.isRed {
                return .workRed
            }
            return .work
        }
        if ThreemaAppObjc.isRed {
            return .red
        }
        
        return .threema
    }
    
    private static var isRed: Bool {
        let bundle = BundleUtil.mainBundle()
        return bundle?.bundleIdentifier?.contains(".red") ?? false
    }
    
    @objc public class func currentName() -> String {
        let bundle = BundleUtil.mainBundle()
        return bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    }
}
