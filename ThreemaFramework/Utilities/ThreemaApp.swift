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

import Foundation

public enum ThreemaApp {
    case threema
    case work
    case green
    case blue
    case onPrem
    
    public static var current: ThreemaApp = {
        if LicenseStore.isOnPrem() {
            return .onPrem
        }
        else if LicenseStore.requiresLicenseKey() {
            if isSandbox {
                return .blue
            }
            return .work
        }
        if isSandbox {
            return .green
        }
        
        return .threema
    }()
    
    /// Returns the CFBundleName for the current process. E.g. `ThreemaShareExtension` for the share extension or
    /// `Threema` for the app.
    /// See `appName`
    public static var currentName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    
    /// Returns the CFBundleName for the app to which the current process belongs. E.g. if we are running in the
    /// ThreemaShareExtension this will return `Threema`.
    /// See `currentName`
    public static var appName: String = BundleUtil.mainBundle()?
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    /// Link to open for writing an AppStore review
    public static var rateLink: URL? = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "ThreemaRateLink") as? String,
              let url = URL(string: string) else {
            return nil
        }
        
        return url
    }()
    
    private static var isSandbox: Bool = {
        let bundle = BundleUtil.mainBundle()
        return bundle?.bundleIdentifier?.contains(".red") ?? false
    }()
}

@objc public class ThreemaAppObjc: NSObject {
    @objc public enum ThreemaApp: Int, RawRepresentable {
        case threema
        case work
        case green
        case blue
        case onPrem
    }
    
    @objc public class func current() -> ThreemaApp {
        if LicenseStore.isOnPrem() {
            return .onPrem
        }
        else if LicenseStore.requiresLicenseKey() {
            if ThreemaAppObjc.isSandbox {
                return .blue
            }
            return .work
        }
        if ThreemaAppObjc.isSandbox {
            return .green
        }
        
        return .threema
    }
    
    private static var isSandbox: Bool = {
        let bundle = BundleUtil.mainBundle()
        return bundle?.bundleIdentifier?.contains(".red") ?? false
    }()
    
    @objc public class func appName() -> String {
        let bundle = BundleUtil.mainBundle()
        return bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    }
}
